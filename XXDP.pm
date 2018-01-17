package XXDP;

require 5.008;

# options
use strict;
	
# external standard modules
use FindBin;
use FileHandle;
use File::Spec;
use File::Basename;
use File::Path qw( make_path );
use Data::Dumper;
use Time::Local;
use List::Util qw( min max );

# external local modules search path
BEGIN { unshift(@INC, $FindBin::Bin);
        unshift(@INC, '.'); }

#----------------------------------------------------------------------------------------------------
#
# P U B L I C   M e t h o d s
#
#----------------------------------------------------------------------------------------------------

# table of standard XXDP device filesystem layouts

my %db = ( # *** MFD1/MFD2 type, format 1 ***
	   #
	   TU58  => { BOOT => [0], MFD => [1,2], UFD => [3..6],   MAP => [7],        MON => [8..39],    SIZE => 512,   DRIVER => 'DD.SYS' },
	   TU58X => { BOOT => [0], MFD => [1,2], UFD => [3..6],   MAP => [7],        MON => [8..38],    SIZE => 512,   DRIVER => 'DD.SYS' }, # legacy XXDPDIR uses MON size 31 vs 32
	   #
	   RX01  => { BOOT => [0], MFD => [1,2], UFD => [3..6],   MAP => [7],        MON => [8..39],    SIZE => 494,   DRIVER => 'DX.SYS' },
	   RX02  => { BOOT => [0], MFD => [1,2], UFD => [3..18],  MAP => [19..22],   MON => [23..54],   SIZE => 988,   DRIVER => 'DY.SYS' },
	   #
	   RP02  => { BOOT => [0], MFD => [1,2], UFD => [3..172], MAP => [173..222], MON => [223..254], SIZE => 48000, DRIVER => 'DP.SYS' },
	   RP04  => { BOOT => [0], MFD => [1,2], UFD => [3..172], MAP => [173..222], MON => [223..254], SIZE => 48000, DRIVER => 'DB.SYS' },
	   #
	   # *** MFD1/MFD2 type, format 2 ***
	   #
	   TU56  => { BOOT => [0], MFD => [64,65], UFD => [66..67], MAP => [68], MON => [24..39], INTERLEAVE => 5, SIZE => 576, DRIVER => 'DT.SYS' }, # 578 physical, XXDP only uses 576
	   #
	   # *** MFD1/MFD2 type, format 3 ***
	   #
	 ##RK05  => { BOOT => [0], MFD => [1,4794], UFD => [3..18], MAP => [4795..4799], MON => [30..61], INTERLEAVE => 5, SIZE => 4800, DRIVER => 'DK.SYS' }, # documented block usage disagrees with available images
	   #
	   # *** MFD type, format 1 ***
	   #
	   RL01  => { BOOT => [0], MFD => [1], MAP => [2..23], UFD => [24..169], MON => [170..201], BAD => [10220..10239], SIZE => 10220, DRIVER => 'DL.SYS' },
	   RL01X => { BOOT => [0], MFD => [1], MAP => [2..23], UFD => [24..169], MON => [170..199], BAD => [10220..10239], SIZE => 10220, DRIVER => 'DL.SYS' }, # version per doc is BAD ... MON too small, 30 vs 32
	   RL02  => { BOOT => [0], MFD => [1], MAP => [2..23], UFD => [24..169], MON => [170..201], BAD => [20460..20479], SIZE => 20460, DRIVER => 'DL.SYS' },
	   #
	   RK06  => { BOOT => [0], MFD => [1], MAP => [2..30], UFD => [31..126], MON => [127..158], BAD => [27104..27125], SIZE => 27104, DRIVER => 'DM.SYS' },
	   RK07  => { BOOT => [0], MFD => [1], MAP => [2..30], UFD => [31..126], MON => [127..158], BAD => [53768..53789], SIZE => 53768, DRIVER => 'DM.SYS' },
	   #
	   RM03  => { BOOT => [0], MFD => [1], MAP => [2..51], UFD => [52..221], MON => [222..254], SIZE => 48000, DRIVER => 'DR.SYS' },
	   #
	   # *** MFD type, format 2 ***
	   #
	   MSCP  => { BOOT => [0], MFD => [1], MSC => [2], MON => [3..34], UFD => [35..268], MAP => [269..337], SIZE => 65535, DRIVER => 'DU.SYS' },
	   #
    );

my %xl = ( # table of translations
	   NONE => 'MSCP',
	   RP05 => 'RP04', RP06 => 'RP04',
	   RP03 => 'RP02',
	   RM05 => 'RM03',
	   RD54 => 'MSCP',
    );

#----------------------------------------------------------------------------------------------------

# RX01/RX02 words/sector, bytes/sector, and sectors/track

my %rxdb = ( RX01 => { WPS =>  64, BPS => 128, SPT => 26 },
             RX02 => { WPS => 128, BPS => 256, SPT => 26 } );

#----------------------------------------------------------------------------------------------------

# create a new base object
#
# returns handle to the oject class

sub new {

    my ($class, %arg) = @_;

    # class setup
    my $self = {};
    bless $self, $class;

    # initialization
    $self->{WARN} = 0; # no warnings enabled
    $self->{DEBUG} = 0; # no debug messages
    $self->{VERBOSE} = 0; # quiet message mode
    $self->{VERSION} = '1.2'; # our code version

    # global arguments
    $self->{WARN} = $arg{-warn} if exists $arg{-warn};
    $self->{DEBUG} = $arg{-debug} if exists $arg{-debug};
    $self->{VERBOSE} = $arg{-verbose} if exists $arg{-verbose};

    # defaults
    $self->{VERBOSE} = 1 if $self->{DEBUG} >= 1; # debug implies verbose messages

    # say hello
    printf STDERR "%s %s %s (perl %g)\n", $0, $class, $self->{VERSION}, $] if $self->{DEBUG};

    # default data
    $self->default();

    # user supplied arguments
    $self->{path} = $arg{-path} if exists $arg{-path};
    $self->{image} = $arg{-image} if exists $arg{-image};
    $self->{device} = uc($arg{-device}) if exists $arg{-device};

    # done
    return $self;
}

#----------------------------------------------------------------------------------------------------

# return version number

sub version {

    my ($self) = @_;

    return $self->{VERSION};
}

#----------------------------------------------------------------------------------------------------

# dump all the values in the data table
#
# return the ascii dump string for printing

sub dump {

    my ($self) = @_;

    $Data::Dumper::Indent = 2;
    $Data::Dumper::Purity = 0;
    $Data::Dumper::Sortkeys = sub { [sort {$a =~ m/^\d+$/ && $b =~ m/^\d+$/ ? $a <=> $b : $a cmp $b} keys %{$_[0]}] };

    my $result = "\n";

    my $s = 0;
    my $c = 0;
    foreach my $line (split("\n", Dumper($self))) {
	$s = 10 if $line =~ m/^\s+'boot'\s+=>/;
	$s = 20 if $line =~ m/^\s+'mfd\d'\s+=>/;
	$s = 30 if $line =~ m/^\s+'map'\s+=>/;
	$s = 40 if $line =~ m/^\s+'ufd'\s+=>/;
	$s++ if $line =~ m/\[/;
	$s-- if $line =~ m/\]/;
	$c = 0 if $s % 10 == 1;
	if ($line =~ m/^(\s+)(\d+)(,?)/) {
	    if ($s % 10 == 2) {
		$result .= sprintf("%s", $1) if $c % 8 == 0;
		$result .= sprintf("%06o%s", $2,$3);
		$result .= sprintf("\n") if $c % 8 == 7;
		$c++;
	    } else {
		$result .= sprintf("%s%06o%s\n", $1,$2,$3);
	    }
	} else {
	    $result .= sprintf("%s\n", $line);
	}
    }
    $result .= "\n";

    return $result;
}

#----------------------------------------------------------------------------------------------------

# test print arguments
#
# return the listing as a string for printing

sub test {

    my ($self, %arg) = @_;

    # arguments
    my $pattern = exists $arg{-pattern} ? $arg{-pattern} : ['blank'];

    # print arguments
    foreach my $entry (@$pattern) {
	printf STDERR "test: entry='%s'\n", $entry;
    }
    printf STDERR "\n";

    return '';
}

#----------------------------------------------------------------------------------------------------

# open a disk for access, must exist and be initialized
#
# return 0 on success, else count of errors

sub open {

    my ($self) = @_;

    # get filehandle, open existing file, return if failure
    $self->{disk} = new FileHandle;
    return 1 unless sysopen($self->{disk}, $self->{image}, O_RDWR|O_BINARY);

    # figure out device layout to use
    my $device = exists($xl{$self->{device}}) ? $xl{$self->{device}} : $self->{device};

    # read the MFD block(s)
    my $mfd1blk = $db{$device}{MFD}->[0];			# block number of MFD1 or MFD1/2 block
    $self->{mfd1} = [$mfd1blk,0,[$self->readblk($mfd1blk)]];	# MFD1 or MFD1/2 block
    $self->{mfd2} = [$self->mfdnxt,0,[$self->readblk($self->mfdnxt)]] if $self->mfdnxt > 0 && $self->mfdnxt < $db{$device}{SIZE}; # MFD2 block if present

    # fake out the MFD blocks on a TU56 image that does not have valid data in the MFD1 block
    if ($device eq 'TU56' && ($self->{mfd1}[2]->[0] <= 0 || $self->{mfd1}[2]->[0] >= $db{$device}{SIZE} ||
			      $self->{mfd1}[2]->[2] <= 0 || $self->{mfd1}[2]->[2] >= $db{$device}{SIZE} ||
			      $self->{mfd1}[2]->[3] <= 0 || $self->{mfd1}[2]->[3] >= $db{$device}{SIZE} )) {
	# fake the MFD block(s)
	printf STDERR "Generating virtual MFD1/MFD2 blocks\n" if $self->{DEBUG} >= 2;
	# MFD1 block
	my @map = @{$db{$device}{MAP}};
	$self->{mfd1} = [$db{$device}{MFD}->[0], 0, [$db{$device}{MFD}->[1],
						     $db{$device}{INTERLEAVE},
						     $map[0],
						     @map,
						     (0) x (253-scalar(@map))]];
	# MFD2 block
	$self->{mfd2} = [0, 0, [0, 0401, $db{$device}{UFD}->[0], 9, (0) x 252]];
    }

    # debug print the MFD block(s)
    if ($self->{DEBUG} >= 2) {
	foreach my $t ('mfd1','mfd2') {				# iterate over types
	    next unless defined $self->{$t};			# check if type exists
	    my ($blk,$chg,$dat) = @{$self->{$t}};		# retrieve the data
	    printf STDERR "%s block at %06o:\n", uc($t),$blk;
	    printf STDERR "  (%s,\n", join(',',map {sprintf("%06o",$_)} @$dat[0..15]);
	    foreach my $i (1..14) { printf STDERR "   %s,\n", join(',',map {sprintf("%06o",$_)} @$dat[(16*$i+0)..(16*$i+15)]); }
	    printf STDERR "   %s)\n", join(',',map {sprintf("%06o",$_)} @$dat[240..255]);
	}
    }

    # sanity checks
    warn sprintf("MFD UFDlen error: %d <> %d", $self->ufdlen, 9) unless $self->ufdlen == 9; # must use 9. word dir entry

    # get overall size of the image, in bytes
    $self->{bytes} = ($self->{disk}->stat)[7];
    # for devices RX01/RX02, fix size by removing track 0 sectors from overall size count
    $self->{bytes} -= $rxdb{$device}{SPT}*$rxdb{$device}{BPS} if $device eq 'RX01' || $device eq 'RX02';

    # read UFD blocks
    if ($self->ufdblk != 0) {

	# process UFD blocks
	my $ufdptr = $self->ufdblk;				# next UFD ptr
	$self->ufdnum(0);					# init UFD block count
	until ($ufdptr == 0) {					# done when link goes to zero
	    my @ufd = $self->readblk($ufdptr);			# read next UFD block
	    $self->ufdnum($self->ufdnum+1);			# count UFD blocks
	    $self->{ufd}{$self->ufdnum} = [$ufdptr,0,[@ufd]];	# store UFD block
	    $ufdptr = $ufd[0];					# link to next UFD block
	}

	# debug print all UFDs seen
	if ($self->{DEBUG} >= 2) {
	    foreach my $i (sort({$a<=>$b}keys(%{$self->{ufd}}))) { # iterate over UFD blocks in order
		my ($blk,$chg,$ufd) = @{$self->{ufd}{$i}};         # retrieve UFD block
		printf STDERR "UFD block %d. at %06o:\n", $i,$blk;
		my $j = $self->ufdlen;
		for (my $k = 1; $k+$j-1 < $self->{blklen}; $k += $j) {
		    my @t = @$ufd[$k..($k+$j-1)];
		    my $d = sprintf("  %s.%s  %s", &_rad2asc($t[0],$t[1]), &_rad2asc($t[2]), &_date2asc($t[3]));
		    $d = '' if $t[0] == 0 && $t[1] == 0;
		    printf STDERR "  %2d:(%s)%s\n", ($k-1)/$j, join(',',map {sprintf("%06o",$_)} @t), $d;
		}
	    }
	}

    }

    # read MAP blocks
    if ($self->mapblk != 0) {

	# process MAP blocks
	my $mapptr = $self->mapblk;				# next MAP ptr
	$self->mapnum(0);					# init MAP block count
	until ($mapptr == 0) {					# done when link goes to zero
	    my @map = $self->readblk($mapptr);			# read next MAP block from linked
	    $self->mapnum($self->mapnum+1);			# count MAP blocks
	    # fix MAP blocks on TU56 device image
	    if ($device eq 'TU56') {
		# zap extra unused map words above length value
		foreach my $i ($map[2]..251) { $map[$i+4] = 0; }
		# set length to standard value
		$map[2] = $self->maplen;
	    }
	    if ($self->{WARN}) {
		warn "MAP ptr error" unless $map[3] == $self->mapblk;   # must point to first block
		warn "MAP size error" unless $map[2] == $self->maplen;  # size must exact
		warn "MAP count error" unless $map[1] == $self->mapnum; # must match index
		## next unless $map[3] == $self->mapblk && $map[2] == $self->maplen && $map[1] == $self->mapnum;
	    }
	    $self->{map}{$self->mapnum} = [$mapptr,0,[@map]];	# store MAP block
	    $mapptr = $map[0];					# link to next MAP block
	}

	# scan MAP to find total number of blocks used
	$self->usenum(0);					# init blocks used count
	foreach my $i (keys(%{$self->{map}})) {			# iterate over MAP blocks
	    my ($blk,$chg,$map) = @{$self->{map}{$i}};		# retrieve MAP block
	    $self->usenum($self->usenum+&_countones(@$map[4..63])); # count all the ones in the MAP
	}

	if ($self->mfdnxt == 0) {
	    # MFD1/2 has supported number of blocks, but max still dictated by bitmap
	    $self->supnum($self->mapnum*16*$self->maplen) if $self->mapnum*16*$self->maplen < $self->supnum;
	} else {
	    # MFD1/MFD2 does not indicate number of blocks, so use the bitmap block count
	    $self->supnum($self->mapnum*16*$self->maplen);
	}
	# size of file dictates maximum number of blocks supported
	$self->supnum($self->actnum) if $self->actnum < $self->supnum;

	# never allow number of supported blocks be larger than the 16b maximum
	$self->supnum(65535) if 65535 < $self->supnum;

	# debug print all MAPs seen
	if ($self->{DEBUG} >= 2) {
	    foreach my $i (sort({$a<=>$b}keys(%{$self->{map}}))) { # iterate over MAP blocks in order
		my ($blk,$chg,$map) = @{$self->{map}{$i}};         # retrieve MAP block
		printf STDERR "MAP block %d. at %06o:\n", $i,$blk;
		printf STDERR "  (%s,\n", join(',',map {sprintf("%06o",$_)} @$map[0..3]);
		printf STDERR "   %s,\n", join(',',map {sprintf("%06o",$_)} @$map[4..18]);
		printf STDERR "   %s,\n", join(',',map {sprintf("%06o",$_)} @$map[19..33]);
		printf STDERR "   %s,\n", join(',',map {sprintf("%06o",$_)} @$map[34..48]);
		printf STDERR "   %s)\n", join(',',map {sprintf("%06o",$_)} @$map[49..63]);
	    }
	}

    }

    return 0;
}

#----------------------------------------------------------------------------------------------------

# close an open disk file, but write out any changed overhead blocks first
#
# return 0 on success, else count of errors

sub close {

    my ($self) = @_;

    # count any errors seen
    my $error = 0;

    # write the MFD block(s) that have changed (possible, not likely)
    foreach my $t ('mfd1','mfd2') {
	next unless defined $self->{$t};			# check if block exists
	my ($blk,$chg,$dat) = @{$self->{$t}};			# retrieve the data
	next unless $chg;				        # next iteration if unchanged
	$self->writeblk($blk,$dat);				# write the updated block
	$self->{$t}[1] = 0;					# no longer changed
	if ($self->{DEBUG} >= 2) {
	    printf STDERR "%s block at %06o was UPDATED\n", uc($t),$blk;
	}
    }

    # write updated UFD blocks
    if ($self->ufdblk != 0) {

	# process UFD blocks that have changed
	foreach my $i (sort({$a<=>$b}keys(%{$self->{ufd}}))) { # iterate over UFD blocks in order
	    my ($blk,$chg,$ufd) = @{$self->{ufd}{$i}};         # retrieve UFD block
	    next unless $chg;				       # next iteration if unchanged
	    $self->writeblk($blk,$ufd);			       # write the updated UFD block
	    $self->{ufd}{$i}[1] = 0;			       # no longer changed
	    if ($self->{DEBUG} >= 2) {
		printf STDERR "UFD block %d. at %06o was UPDATED:\n", $i,$blk;
		my $j = $self->ufdlen;
		for (my $k = 1; $k+$j-1 < $self->{blklen}; $k += $j) {
		    printf STDERR "  %2d:(%s)\n", ($k-1)/$j, join(',',map {sprintf("%06o",$_)} @$ufd[$k..($k+$j-1)]);
		}
	    }
	}

    }

    # write updated MAP blocks
    if ($self->mapblk != 0) {

	# process MAP blocks that have changed
	foreach my $i (sort({$a<=>$b}keys(%{$self->{map}}))) { # iterate over MAP blocks in order
	    my ($blk,$chg,$map) = @{$self->{map}{$i}};         # retrieve MAP block
	    next unless $chg;				       # next iteration if unchanged
	    $self->writeblk($blk,$map);			       # write the updated MAP block
	    $self->{map}{$i}[1] = 0;			       # no longer changed
	    if ($self->{DEBUG} >= 2) {
		printf STDERR "MAP block %d. at %06o was UPDATED:\n", $i,$blk;
		printf STDERR "  (%s,\n", join(',',map {sprintf("%06o",$_)} @$map[0..3]);
		printf STDERR "   %s,\n", join(',',map {sprintf("%06o",$_)} @$map[4..18]);
		printf STDERR "   %s,\n", join(',',map {sprintf("%06o",$_)} @$map[19..33]);
		printf STDERR "   %s,\n", join(',',map {sprintf("%06o",$_)} @$map[34..48]);
		printf STDERR "   %s)\n", join(',',map {sprintf("%06o",$_)} @$map[49..63]);
	    }
	}

    }

    # all done
    CORE::close($self->{disk});
    $self->default;

    return $error;
}

#----------------------------------------------------------------------------------------------------

# print a directory listing
#
# return the listing as a string for printing

sub directory {

    my ($self, %arg) = @_;

    # arguments
    my $pattern = exists $arg{-pattern} ? $arg{-pattern} : ['*.*'];
    my $format = exists $arg{-format} ? lc($arg{-format}) : 'standard'; # or 'extended', 'diagdir', or 'xxdp'

    my $result = '';
    my $blocks = 0;
    my $overhead = 1;

    if ($format eq 'diagdir') {

	# legacy diagdir/xxdpdir header format

	$result .= "\nWill's Works PDP-11 XXDP Image Viewer  Version: 1.02\n\n";
	if ($self->mfdnxt == 0) {
	    # MFD1/2 format
	    $result .= sprintf("image supports %d blocks, %d are pre-allocated\n", $self->supnum, $self->prenum);
	    $result .= sprintf("XXDP format, monitor starts at block %d\n", $self->monblk);

	} else {
	    # MFD1/MFD2 format
	    $result .= sprintf("%d directory blocks, ending in block %d\n", $self->ufdnum, $self->ufdblk+$self->ufdnum-1);
	    $result .= sprintf("Assume DOSBATCH device with %d blocks\n", $self->supnum);
	    $result .= sprintf("DOSBATCH format, assume monitor starts at block %d\n", $self->mapblk+$self->mapnum);
	}
	$result .= sprintf("%d blocks in bitmap %d device blocks in use\n", $self->mapnum, $self->usenum);
	$result .= sprintf("Attempting dir starting at block %d  LIST ALL\n", $self->ufdblk);

    } else {

	# XXDP / new header format

	if ($self->mfdnxt == 0) {
	    # MFD1/2 format
	    $result .= sprintf("XXDP format, monitor starts at block %d\n", $self->monblk);
	    $result .= sprintf("Image supports %d blocks, %d are pre-allocated\n", $self->supnum, $self->prenum);
	    $overhead += 1;
	} else {
	    # MFD1/MFD2 format
	    $result .= sprintf("DOS11 format, assume monitor starts at block %d\n", $self->mapblk+$self->mapnum);
	    $result .= sprintf("Image supports %d blocks\n", $self->supnum);
	    $overhead += 2;
	}

	if ($self->ufdnum == 1) {
	    $result .= sprintf("%d directory block, block %d\n", $self->ufdnum, $self->ufdblk);
	} else {
	    $result .= sprintf("%d directory blocks, block %d thru %d\n", $self->ufdnum, $self->ufdblk, $self->ufdblk+$self->ufdnum-1);
	}
	$overhead += $self->ufdnum;

	if ($self->mapnum == 1) {
	    $result .= sprintf("%d bitmap block, block %d\n", $self->mapnum, $self->mapblk);
	} else {
	    $result .= sprintf("%d bitmap blocks, block %d thru %d\n", $self->mapnum, $self->mapblk, $self->mapblk+$self->mapnum-1);
	}
	$overhead += $self->mapnum;

	$result .= sprintf("%d device blocks in use according to the bitmap\n", $self->usenum);

	$result .= "\nENTRY# FILNAM.EXT        DATE          LENGTH  START   VERSION\n\n" unless $format eq 'diagdir';

    }

    # scan UFD entries in order, print them out
    for (my $index = 1; $index <= $self->ufdentrynum; ++$index) {

	# get elements of current UFD entry
	my ($file1,$file2,$extn,$date,$actend,$start,$length,$last,$act52) = $self->ufdentry($index);

	# skip deleted file entries
	next if $file1 == 0 && $file2 == 0 && $extn == 0;

	# decode filename
	my $filename = &_rad2asc($file1,$file2); # decode filename
	my $fileextn = &_rad2asc($extn);         # decode extension
	my $realdate = &_date2asc($date);        # decode DEC date

	# iterate over all patterns, looking for a match
	my $match = 0;
	foreach my $entry (@$pattern) {
	    # count file matches
	    $match++ if &_file_matches($entry,$filename,$fileextn);
	}
	# file did not match any pattern
	next if $match == 0;

	# read first block to get file type/version
	my $first = $self->readblk($start);

	# system files .SYS have a defined binary version ID
	my $sysfile = $fileextn eq 'SYS' && $first->[1]==1;
	my $version = $sysfile && $first->[8]!=0 ? chr(($first->[8]>>0)&0xFF).'.'.chr(($first->[8]>>8)&0xFF) : '';
	$version = '' unless $version =~ m/^[A-Z][.][0-9]$/; # only valid format allowed

	# print selected file(s)
	if ($format eq 'diagdir') {
	    # the way that XXDPDIR.EXE/DIAGDIR.EXE prints it
	    $result .= sprintf("%3d:  %6s.%3s  %9s %4d blocks start %4d  end %4d", $index,$filename,$fileextn,$realdate,$length,$start,$last);
	    $result .= sprintf("   %s", $version) if $version ne '';
	    $result .= " - Contiguous" if $fileextn eq 'SAV';
	} elsif ($format eq 'xxdp') {
	    # the way that XXDPv2 DIR command prints it
	    $result .= sprintf("%5d  %6s.%3s      %9s     %6d    %06o", $index,$filename,$fileextn,$realdate,$length,$start);
	    $result .= sprintf("   %s", $version) if $version ne '';
	    $result .= " - Contiguous" if $fileextn eq 'SAV';
	} else {
	    # slight modification of XXDPv2 DIR command with decimal only
	    $result .= sprintf("%5d  %6s.%3s      %9s      %6d %6d", $index,$filename,$fileextn,$realdate,$length,$start);
	    $result .= sprintf("     %s", $version) if $version ne '';
	    $result .= " - Contiguous" if $fileextn eq 'SAV';
	}
	$result .= "\n";

	# count blocks
	$blocks += $length;

	# check that all blocks in file are mapped as used, compare allocated length vs expected length
	if ($self->{WARN}) {
	    my $count = 0;
	    if ($fileextn eq 'SAV') {
		# contiguous file
		for (my $blk = $start; $blk <= $last && $blk < $self->supnum; ++$blk) {
		    my @data = $self->readblk($blk);
		    warn sprintf("Warning file %s.%s block %06o is unmapped",
				 &_strp($filename),&_strp($fileextn),$blk)
			unless $self->mapentry($blk) == 1;
		    $count += 1;
		}
	    } else {
		# linked file
		for (my $blk = $start; $blk != 0 && $blk < $self->supnum; ) {
		    my @data = $self->readblk($blk);
		    warn sprintf("Warning file %s.%s block %06o is unmapped",
				 &_strp($filename),&_strp($fileextn),$blk)
			unless $self->mapentry($blk) == 1;
		    $count += 1;
		    $blk = $data[0];
		    warn sprintf("Warning file %s.%s link pointer %06o is invalid",
				 &_strp($filename),&_strp($fileextn),$blk)
			unless $blk < $self->supnum;
		}
	    }
	    warn sprintf("Warning file %s.%s expected length %d. <> allocated length %d.",
			 &_strp($filename),&_strp($fileextn),$length,$count)
		unless $length == $count;
	}

	# print file contents if requested
	if ($self->{DEBUG} >= 3) {
	    # dump file contents if requested
	    printf STDERR "DUMP %6s.%3s  %9s %5d blocks start %5d end %5d\n",
			   $filename,$fileextn,$realdate,$length,$start,$last;
	    if ($fileextn eq 'SAV') {
		# contiguous file
		for (my $blk = $start; $blk <= $last && $blk < $self->supnum; ++$blk) {
		    my @data = $self->readblk($blk);
		    my $char;
		    for (my $i = 0; $i <= $#data; ++$i) {
			printf STDERR "%06o:", $blk if $i == 0;
			if ($i % 8 == 0 && $i > 0) { printf STDERR "       "; $char = ""; }
			printf STDERR " %06o", $data[$i];
			$char .= &_mapchr($data[$i]) . &_mapchr($data[$i]>>8);
			printf STDERR " %s\n", $char if $i % 8 == 7;
		    }
		}
	    } else {
		# linked file
		for (my $blk = $start; $blk != 0 && $blk < $self->supnum; ) {
		    my @data = $self->readblk($blk);
		    my $char;
		    for (my $i = 0; $i <= $#data; ++$i) {
			printf STDERR "%06o:", $blk if $i == 0;
			if ($i % 8 == 0 && $i > 0) { printf STDERR "       "; $char = ""; }
			printf STDERR " %06o", $data[$i];
			$char .= &_mapchr($data[$i]) . &_mapchr($data[$i]>>8);
			printf STDERR " %s\n", $char if $i % 8 == 7;
		    }
		    $blk = $data[0];
		}
	    }
	}

    } # for my $index

    # old way has no summary
    return $result if $format eq 'diagdir';

    # xxdp adds free block info
    $result .= "\n";
    $result .= sprintf("FREE BLOCKS: %5d\n", $self->supnum-$self->usenum);
    return $result if $format ne 'extended';
    
    # extended adds lots more info
    $result .= "\n";
    $result .= sprintf("Bitmap used block count: %6d\n", $self->usenum);
    $result .= sprintf("File block count:        %6d\n", -$blocks);
    $result .= sprintf("Overhead block count:    %6d\n", -$overhead);
    $result .=         "                         ------\n";
    $result .= sprintf("Extra used block count:  %6d  (monitor area)\n", $self->usenum-$blocks-$overhead);
    $result .= "\n";
    $result .= sprintf("Device block count:      %6d\n", $self->supnum);
    $result .= sprintf("Bitmap used block count: %6d\n", -$self->usenum);
    $result .=         "                         ------\n";
    $result .= sprintf("Free block count:        %6d\n", $self->supnum-$self->usenum);
    return $result;
}

#----------------------------------------------------------------------------------------------------

# extract files matching pattern

sub extract {

    my ($self, %arg) = @_;

    # arguments
    my $pattern = exists $arg{-pattern} ? $arg{-pattern} : ['*.*'];
    my $path = exists $arg{-path} ? $arg{-path} : $self->{path};
    my $data = exists $arg{-data} ? $arg{-data} : undef;

    my $result = '';
    my $count = 0;

    # iterate over all UFD entries
    for (my $index = 1; $index <= $self->ufdentrynum; ++$index) {

	# get elements of currrent UFD entry
	my ($file1,$file2,$extn,$date,$actend,$start,$length,$last,$act52) = $self->ufdentry($index);

	# skip deleted file entries
	next if $file1 == 0 && $file2 == 0 && $extn == 0;

	# decode filename
	my $filename = &_rad2asc($file1,$file2); # decode filename
	my $fileextn = &_rad2asc($extn);         # decode extension
	my $realdate = &_date2asc($date);        # decode DEC date

	# iterate over all patterns, looking for a match
	my $match = 0;
	foreach my $entry (@$pattern) {
	    # count file matches
	    $match++ if &_file_matches($entry,$filename,$fileextn);
	}
	# file did not match any pattern
	next if $match == 0;

	# print selected file(s)
	$result .= sprintf("Extract: %4d:  %6s.%3s  %9s %5d blocks start %5d end %5d\n",
			   $index,$filename,$fileextn,$realdate,$length,$start,$last) if $self->{VERBOSE};

	# full filename
	my $file = &_strp($filename.'.'.$fileextn);

	# read all blocks of the file to an array
	my @data = ();

	if ($fileextn eq 'SAV') {

	    # core image file, contiguous data image with 256. words of data per block

	    # loop over all blocks
	    for (my $blk = $start; $blk <= $last && $blk < $self->supnum; ++$blk) {
		# read a block
		my @tmp = $self->readblk($blk);
		# pack words into buffer and write to file
		push(@data, @tmp);
	    }

	} else {

	    # linked block file, first word is link to next block, followed by 255. words of data

	    # loop until next block goes to zero
	    for (my $blk = $start; $blk != 0 && $blk < $self->supnum; ) {
		# read a block
		my @tmp = $self->readblk($blk);
		# remove link to next block
		$blk = shift(@tmp);
		# pack words into buffer and write to file
		push(@data, @tmp);
	    }

	}

	if (defined($data)) {

	    # caller wants data returned

	    $$data[$count] = [ $index, $file, \@data ];

	} else {

	    # caller wants data extracted to a file

	    # create output folder if does not exist
	    make_path($path);

	    # merged path/file, prune blanks
	    my $name = File::Spec->catfile($path, $file);

	    # open a filehandle for writing, binary mode
	    my $fh = new FileHandle $name, "w";
	    binmode($fh);

	    # write all the data
	    $fh->print(pack("v*",@data));
	
	    # we are done, count files
	    $fh->close;

	    # set the access and modification times from the source media
	    utime(&_date2stamp($date), &_date2stamp($date), $name);

	}

	# count files
	$count++;
    }
    $result .= sprintf("Extracted %d files\n", $count) if $self->{VERBOSE};

    return $result;
}

#----------------------------------------------------------------------------------------------------

# insert files matching pattern

sub insert {

    my ($self, %arg) = @_;

    # arguments
    my $pattern = exists $arg{-pattern} ? $arg{-pattern} : ['*.*'];
    my $path = exists $arg{-path} ? $arg{-path} : $self->{path};

    my $result = '';
    my $count = 0;

    # get all filenames in the source directory that match pattern
    my @files = ();
    opendir(DIR, $path);
    foreach my $filename (sort(readdir(DIR))) {
	my $match = 0;
	# iterate over all patterns, looking for a match
	foreach my $entry (@$pattern) {
	    # count file matches
	    $match++ if &_file_matches($entry,$filename);
	}
	# save files that match
	push(@files, $filename) if $match;
    }
    closedir(DIR);

    # iterate over all file names selected
    foreach my $file (@files) {

	# merged path/file, prune blanks
	my $name = File::Spec->catfile($path, $file);

	# skip files that don't exist, or are zero size, or are not plain files
	next if ! -e $name || ! -f $name || -z $name;

	# open a filehandle for reading, binary mode
	my $fh = new FileHandle $name, "r";
	binmode($fh);

	# data buckets
	my $data = undef;
	my @data = ();

	# read all the data, use optimal host blocksize
	while (my $size = $fh->read($data, (stat($fh))[11])) {
	    push(@data, unpack("v*",$data));
	}
	
	# last modified date for the file
	my ($dd,$mm,$yy) = (localtime((stat($fh))[9]))[3,4,5];

	# we are done
	$fh->close;

	# split file into name and extension parts
	my ($filename, $filepath, $fileextn) = fileparse($name, qr/\.[^.]*$/);
	# drop the leading dot from the extension
	$fileextn = substr($fileextn,1);
	# and build the last modified date
	my $realdate = sprintf("%02d-%s-%04d",
			       $dd,
			       ('JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC')[$mm],
			       $yy+1900);

	# encode filename for DOS11
	my ($file1,$file2) = &_asc2rad(sprintf("%-6s",$filename)); # encode filename
	my $extn =           &_asc2rad($fileextn);                 # encode extension
	my $date =           &_asc2date($realdate);                # encode DEC date

	# (re)decode filename
	$filename = &_rad2asc($file1,$file2); # decode filename
	$fileextn = &_rad2asc($extn);         # decode extension
	$realdate = &_date2asc($date);        # decode DEC date

	# delete file if already exists
	$result .= $self->delete( -summary => 0, -pattern => [&_strp($filename.'.'.$fileextn)] );

	# get next free UFD entry
	my $index = $self->ufdfree();

	# if no more left ... :-(
	return $result.sprintf("ERROR: no more free UFD entries; directory is full!\n") if $index == 0;

	# current block used
	my $current = 1;
	# allocate all blocks needed
	my @list = ();
	# get location of blocks on disk
	my ($length,$start,$last) = (0,0,0);

	do { # loop until a solution is found with enough contiguous blocks (if required) or enough blocks

	    # loop while more data, allocating blocks
	    @list = ();
	    my @tmp = @data;
	    my $ovhd = $fileextn eq 'SAV' ? 0 : 1;
	    while ($current && @tmp) {
		push(@list, $current = $self->mapfree($current+1));
		splice(@tmp, 0, $self->{blklen}-$ovhd);
	    }

	    # get location of blocks on disk
	    ($length,$start,$last) = (scalar(@list), $list[0], $list[-1]);

	    # debug print
	    printf STDERR "name=%s length=%d list=%s\n", $name, $length, join(',',@list) if $self->{DEBUG} >= 2;

	    # reset for next pass, if required
	    $current = $start;

	    # loop for contiguous file request that is not yet satisfied
	} while ($fileextn eq 'SAV' && $last != $start+$length-1 && $last != 0);

	# for contiguous files, the disk blocks must be contiguous
	return $result.sprintf("ERROR: no contiguous free blocks!\n") if $fileextn eq 'SAV' && $last != $start+$length-1;

	# check if last block allocated was OK, else we ran out of space
	return $result.sprintf("ERROR: no more free blocks!\n") if $last == 0;

	# last block link pointer must be null
	push(@list, 0);

	# ok, now we can finally write the data to disk
	while (@data) {
	    # write the data
	    if ($fileextn eq 'SAV') {
		# core image file, contiguous data image with 256. words of data per block
		$self->writeblk($list[0], [splice(@data,0,$self->{blklen})]);
	    } else {
		# linked block file, first word is link to next block, followed by 255. words of data
		$self->writeblk($list[0], [$list[1], splice(@data,0,$self->{blklen}-1)]);
	    }
	    # allocate the entry, shift block list
	    $self->mapentry(shift(@list), 1);
	}	    

	# print selected file(s)
	$result .= sprintf("Insert:  %4d:  %6s.%3s  %9s %5d blocks start %5d end %5d\n",
			   $index,$filename,$fileextn,$realdate,$length,$start,$last) if $self->{VERBOSE};

	# update the directory entry
	$self->ufdentry($index,($file1,$file2,$extn,$date,0,$start,$length,$last,0));

	# count files
	$count++;

    }
    $result .= sprintf("Inserted %d files\n", $count) if $self->{VERBOSE};

    return $result;
}

#----------------------------------------------------------------------------------------------------

# delete files matching pattern

sub delete {

    my ($self, %arg) = @_;

    # arguments
    my $pattern = exists $arg{-pattern} ? $arg{-pattern} : ['*.*'];
    my $summary = exists $arg{-summary} ? $arg{-summary} : 1;

    my $result = '';
    my $count = 0;

    # iterate over all UFD entries
    for (my $index = 1; $index <= $self->ufdentrynum; ++$index) {

	# get elements of current UFD entry
	my ($file1,$file2,$extn,$date,$actend,$start,$length,$last,$act52) = $self->ufdentry($index);

	# skip deleted file entries
	next if $file1 == 0 && $file2 == 0 && $extn == 0;

	# decode filename
	my $filename = &_rad2asc($file1,$file2); # decode filename
	my $fileextn = &_rad2asc($extn);         # decode extension
	my $realdate = &_date2asc($date);        # decode DEC date

	# iterate over all patterns, looking for a match
	my $match = 0;
	foreach my $entry (@$pattern) {
	    # count file matches
	    $match++ if &_file_matches($entry,$filename,$fileextn);
	}
	# file did not match any pattern
	next if $match == 0;

	# print selected file(s) as being deleted
	$result .= sprintf("Deleted: %4d:  %6s.%3s  %9s %5d blocks start %5d end %5d\n",
			   $index,$filename,$fileextn,$realdate,$length,$start,$last) if $self->{VERBOSE};

	# zero the UFD entry to delete the file
	$self->ufdentry($index,(0,0,0,0,0,0,0,0,0));

	# zero bitmap entries for the file to deallocate the blocks
	for (my $blk = $start; $blk != 0; ) {	# loop until next block goes to zero
	    my @data = $self->readblk($blk);	# read a block
	    $self->mapentry($blk,0);		# delete block from bitmap
	    $blk = $data[0];			# link to next block
	}

	# count files
	$count++;

    }
    $result .= $summary ? sprintf("Deleted %d files\n", $count) : '' if $self->{VERBOSE};

    return $result;
}

#----------------------------------------------------------------------------------------------------

# intitialize a disk file as an empty device
#
# return 0 on success, else count of errors

sub init {

    my ($self) = @_;

    # count any errors
    my $error = 0;

    # figure out device layout to use
    my $device = exists($xl{$self->{device}}) ? $xl{$self->{device}} : $self->{device};

    # exit if device layout is not valid
    return -1 unless exists($db{$device});

    # delete file if it already exists
    unlink $self->{image} if -e $self->{image};

    # get filehandle, create new file, return if failure
    $self->{disk} = new FileHandle;
    return -2 unless sysopen($self->{disk}, $self->{image}, O_CREAT|O_TRUNC|O_RDWR|O_BINARY);

    # some shorthand
    my $size = $db{$device}{SIZE};

    # zero the file
    foreach my $i (0..($size-1)) {
	$self->writeblk($i,[(0) x $self->{blklen}]);
    }

    # lists of blocks
    my @boo = @{$db{$device}{BOOT}};
    my @mon = @{$db{$device}{MON}};
    my @ufd = @{$db{$device}{UFD}};
    my @map = @{$db{$device}{MAP}};
    my @mfd = @{$db{$device}{MFD}};
    my @msc = exists($db{$device}{MSC}) ? @{$db{$device}{MSC}} : ();
    my @bad = exists($db{$device}{BAD}) ? @{$db{$device}{BAD}} : ();

    # preallocate overhead blocks
    my %pre = ();
    foreach my $n (@boo) { $pre{$n}++; }
    foreach my $n (@mon) { $pre{$n}++; }
    foreach my $n (@ufd) { $pre{$n}++; }
    foreach my $n (@map) { $pre{$n}++; }
    foreach my $n (@mfd) { $pre{$n}++; }
    foreach my $n (@msc) { $pre{$n}++; }
    if (0) { foreach my $n (@bad) { $pre{$n}++; } } # not included in bitmap

    # optional field settings, either per XXDP+ file document (0) or actual XXDPv25 code (1)
    my $opt = 0;

    # write the MFD block(s)
    if (scalar(@mfd) == 2) {
	# MFD1 block
	my $mfd1 = [(0) x $self->{blklen}];
	$mfd1->[0] = $mfd[1]; # pointer to MFD2
	$mfd1->[1] = 1; # interleave
	$mfd1->[2] = $map[0]; # first MAP block
	for (my $i = 0; $i <= $#map; ++$i) { $mfd1->[3+$i] = $map[$i]; } # all bitmap blocks
	$self->writeblk($mfd[0],$mfd1);
	# MFD2 block
	my $mfd2 = [(0) x $self->{blklen}];
	$mfd2->[0] = 0; # last MFD
	$mfd2->[1] = $opt ? 0x0202 : 0x0101; # uid [2,2] or [1,1]
	$mfd2->[2] = $ufd[0]; # first UFD block
	$mfd2->[3] = $self->ufdlen; # UFD entry length
	$mfd2->[4] = 0; # zero
	$self->writeblk($mfd[1],$mfd2);
    } elsif (scalar(@mfd) == 1) {
	my $mfd = [(0) x $self->{blklen}];
	# MFD block
	$mfd->[0] = 0; # pointer to MFD2 (none)
	$mfd->[1] = $ufd[0]; # pointer to first UFD block
	$mfd->[2] = scalar(@ufd); # number of UFD blocks
	$mfd->[3] = $map[0]; # pointer to first MAP block
	$mfd->[4] = scalar(@map); # number of MAP blocks
	$mfd->[5] = $mfd[0]; # pointer to MFD block
	$mfd->[6] = $opt ? 0x0202 : 0x0000; # unknown/unused
	$mfd->[7] = $size; # number of supported blocks
	$mfd->[8] = scalar(keys(%pre)); # number of preallocated blocks
	$mfd->[9] = 1; # interleave
	$mfd->[10] = 0; # zero
	$mfd->[11] = $mon[0]; # pointer to first MON block
	$mfd->[12] = $opt ? 1 : 0; # unknown/unused
	$mfd->[13] = 0; # track/sector for BAD sector file, SD <<<<================================================================================*****
	$mfd->[14] = 0; # cylinder for BAD sector file, SD     <<<<================================================================================*****
	$mfd->[15] = 0; # track/sector for BAD sector file, DD <<<<================================================================================*****
	$mfd->[16] = 0; # cylinder for BAD sector file, DD     <<<<================================================================================*****
	$self->writeblk($mfd[0],$mfd);
    }

    # write the UFD blocks with zeroed directory entries
    for (my $i = 0; $i <= $#ufd; $i++) {
	my $ufd = [(0) x $self->{blklen}];
	$ufd->[0] = $i == $#ufd ? 0 : $ufd[$i+1];
	$self->writeblk($ufd[$i],$ufd);
    }

    # write the BAD sector mapping table (DEC STD 144) with no bad sectors
    for (my $i = 0; $i <= $#bad; $i++) {
	my $bad = [(0177777) x $self->{blklen}];
	my $id = time; # make up a cartridge ID
	# even blocks get data header, odd blocks are all 1s
	if ($i % 2 == 0) {
	    $bad->[0] = ($id>>0) & 077777;
	    $bad->[1] = ($id>>15) & 077777;
	    $bad->[2] = 000000;
	    $bad->[3] = 000000;
	}
	$self->writeblk($bad[$i],$bad);
    }

    # write the MAP blocks with preallocated bits set
    for (my $i = 0; $i <= $#map; $i++) {
	my $map = [(0) x $self->{blklen}];
	$map->[0] = $i == $#map ? 0 : $map[$i+1];
	$map->[1] = $i+1;
	$map->[2] = $self->maplen;
	$map->[3] = $map[0];
	for (my $w = 0; $w < $self->maplen; ++$w) {
	    for (my $b = 0; $b < 16; ++$b) {
		# compute block number $k represented by bit $b in word $w
		my $k = $b + 16*($w + $self->maplen*$i);
		# always skip out if over device size
		last if $k >= $size;
		# set bit if is allocated
		$map->[4+$w] |= (1<<$b) if exists($pre{$k}) && $pre{$k} == 1;
	    }
	}
	$self->writeblk($map[$i],$map);
    }

    # all done
    CORE::close($self->{disk});

    return $error;
}

#----------------------------------------------------------------------------------------------------

# write boot block and monitor image

sub boot {

    my ($self, %arg) = @_;

    # arguments
    my $pattern = exists $arg{-pattern} ? $arg{-pattern} : ['XXDPSM.SYS'];
    my $device = exists($xl{$self->{device}}) ? $xl{$self->{device}} : $self->{device};

    my $monitor = shift(@$pattern);
    my $driver = $db{$device}{DRIVER};

    # routine to extract data from absolute load formatted binary file data stream
    #
    # Object file format consists of blocks, optionally preceded, separated, and
    # followed by zeroes.  Each block consists of:
    #
    #   001             ---
    #   000             /|\
    #   lo(length)       |
    #   hi(length)       |
    #   lo(address)      |--> 'length' bytes
    #   hi(address)      |
    #   databyte1        |
    #   :               \|/
    #   databyteN       ---
    #   checksum
    #
    sub get_data (@) {
	my @i = @_;  # input byte stream
	my @o = ();  # output data stream
	my $lst = 0; # remember last data record length
	my $flg = 1; # stop after first shorter record if set
	while (@i) {
	    if (scalar(@i) >= 8 && $i[0] == 1 && $i[1] == 0) {
		# compute length, subtract out the 6 overhead bytes
		my $len = 256*$i[3]+$i[2] - 6;
		# address the data starts at
		my $adr = 256*$i[5]+$i[4];
		# flush overhead bytes (flag, zero, length, address)
		splice(@i, 0, 6);
		# extract out the data bytes
		@o[$adr..($adr+$len-1)] = splice(@i, 0, $len);
		# checksum, we don't validate, ignore it for now
		my $chk = splice(@i, 0, 1);
		# exit on first shorter record seen
		last if $flg && $len < $lst;
		# remember last record length
		$lst = $len;
	    } else {
		# flush bytes (usually zero) until we match a record key
		shift(@i);
	    }
	}
	return @o;
    }

    # routine to convert byte array to word array
    #
    sub byte2word (@) {
	my @i = @_;
	my @o = ();
	for (my $n = 0; $n <= $#i; ++$n) {
	    if ($n & 1) { $o[$n>>1] += 256*$i[$n]; } else { $o[$n>>1] = $i[$n]; }
	}
	return @o;
    }

    # routine to convert word array to byte array
    #
    sub word2byte (@) {
	my @i = @_;
	my @o = map {($_>>0)&0377,($_>>8)&0377} @i;
	return @o;
    }

    # some storage
    my @list = ();
    my @files = ();

    # extract the MONITOR file from the device as a data image
    $self->extract( -pattern => [$monitor], -data => \@list );
    my ($indmon,$filmon,$datmon) = @{$list[0]};
    push(@files, $filmon);
    my @monitor = &byte2word(map(defined($_)?$_:0,&get_data(&word2byte(@{$datmon}))));

    # extract the DEVICE DRIVER file from the device as a data image, and isolate the boot block
    $self->extract( -pattern => [$driver], -data => \@list );
    my ($inddrv,$fildrv,$datdrv) = @{$list[0]};
    push(@files, $fildrv);
    my @datdrv = &get_data(&word2byte(@{$datdrv}));
    my $offdrv = 256*$datdrv[7]+$datdrv[6];
    my @boot = &byte2word(map(defined($_)?$_:0,@datdrv[($offdrv+0)..($offdrv+511)]));
    my @drvr = &byte2word(map(defined($_)?$_:0,@datdrv));

    # debug print monitor image
    if ($self->{DEBUG} >= 3) {
	printf STDERR "\nmonitor: monitor='%s'\n", $monitor;
	my $i = 2048;
	foreach my $word (@monitor) {
	    printf STDERR "\n" if $i % 256 == 0;
	    printf STDERR "%07d %07d", $i>>8, 2*$i if $i % 8 == 0;
	    printf STDERR " %03o %03o", ($word>>0)&0377, ($word>>8)&0377;
	    printf STDERR "\n" if $i++ % 8 == 7;
	}
	printf STDERR "\n";
    }

    # debug print boot block image
    if ($self->{DEBUG} >= 3) {
	printf STDERR "\nboot: device='%s' driver='%s'\n", $device, $driver;
	my $i = 0;
	foreach my $word (@boot) {
	    printf STDERR "\n" if $i % 256 == 0;
	    printf STDERR "%07d", 2*$i if $i % 8 == 0;
	    printf STDERR " %03o %03o", ($word>>0)&0377, ($word>>8)&0377;
	    printf STDERR "\n" if $i++ % 8 == 7;
	}
	printf STDERR "\n";
    }

    # debug print device driver image
    if ($self->{DEBUG} >= 3) {
	printf STDERR "\ndriver: device='%s' driver='%s'\n", $device, $driver;
	my $i = 0;
	foreach my $word (@drvr) {
	    printf STDERR "\n" if $i % 256 == 0;
	    printf STDERR "%07d", 2*$i if $i % 8 == 0;
	    printf STDERR " %03o %03o", ($word>>0)&0377, ($word>>8)&0377;
	    printf STDERR "\n" if $i++ % 8 == 7;
	}
	printf STDERR "\n";
    }

    # build a full disk image for the merged monitor
    my @image = @monitor; 
    # block out with zeroes to next multiple of half a block
    while (scalar(@image) % ($self->{blklen}/2)) { push(@image, 0); }
    # add the device driver on the end
    push(@image, @drvr);
    # block out with zeroes to next block multiple
    while (scalar(@image) % $self->{blklen}) { push(@image, 0); }
    # insert boot block as first block of image
    splice(@image, 0, scalar(@boot), @boot);

    # debug print
    if ($self->{DEBUG} >= 2) {
	printf STDERR "\nmonitor: monitor='%s'\n", $monitor;
	my $i = 2048;
	foreach my $word (@image) {
	    printf STDERR "\n" if $i % 256 == 0;
	    printf STDERR "%07d %07d", $i>>8, 2*$i if $i % 8 == 0;
	    printf STDERR " %03o %03o", ($word>>0)&0377, ($word>>8)&0377;
	    printf STDERR "\n" if $i++ % 8 == 7;
	}
	printf STDERR "\n";
    }

    # monitor and boot area block lists
    my @mon = @{$db{$device}{MON}};
    my @boo = @{$db{$device}{BOOT}};

    # check that monitor image will fit in allocated space, bail if it cannot
    if (scalar(@image) > $self->{blklen}*scalar(@mon)) {
	return sprintf("ERROR: monitor image (%d. bytes) too large for allocated space (%d. bytes)!\n",
		       2*scalar(@image), 2*$self->{blklen}*scalar(@mon));
    }

    # write the monitor image to the disk
    foreach my $blk (@mon) {
	if (@image) {
	    # more data, write it
	    $self->writeblk($blk, [splice(@image,0,$self->{blklen})]);
	} else {
	    # no more data, zero fill image
	    $self->writeblk($blk, [(0) x $self->{blklen}]);
	}
    }

    # write the boot image to the disk
    foreach my $blk (@boo) {
	$self->writeblk($blk, [splice(@boot,0,$self->{blklen})]);
    }

    return $self->{VERBOSE} ? sprintf("Boot and monitor blocks written from file(s): %s\n", join(', ',@files)) : '';
}

#----------------------------------------------------------------------------------------------------
#
# P R I V A T E   M e t h o d s
#
#----------------------------------------------------------------------------------------------------

# ptr to second MFD block

sub mfdnxt {
    my ($self,$new) = @_;
    if (defined($new)) {
	# new data and indicate changed
	$self->{mfd1}[2][0] = $new;
	$self->{mfd1}[1] = 1;
    }
    return $self->{mfd1}[2][0];
}

#----------------------------------------------------------------------------------------------------

# ptr to first UFD block

sub ufdblk {
    my ($self,$new) = @_;
    if ($self->mfdnxt == 0) {
	# MFD1/2 block
	if (defined($new)) {
	    # new data and indicate changed
	    $self->{mfd1}[2][1] = $new;
	    $self->{mfd1}[1] = 1;
	}
	return $self->{mfd1}[2][1];
    } else {
	# MFD1/MFD2 blocks
	if (defined($new)) {
	    # new data and indicate changed
	    $self->{mfd2}[2][2] = $new;
	    $self->{mfd2}[1] = 1;
	}
	return $self->{mfd2}[2][2];
    }
}

#----------------------------------------------------------------------------------------------------

# ptr to first BITMAP block

sub mapblk {
    my ($self,$new) = @_;
    if (defined($new)) {
	# new data and indicate changed
	$self->{mfd1}[2][3] = $new;
	$self->{mfd1}[1] = 1;
    }
    return $self->{mfd1}[2][3];
}

#----------------------------------------------------------------------------------------------------

# interleave factor

sub interleave {
    my ($self,$new) = @_;
    if ($self->mfdnxt == 0) {
	# MFD1/2 block
	if (defined($new)) {
	    # new data and indicate changed
	    $self->{mfd1}[2][9] = $new;
	    $self->{mfd1}[1] = 1;
	}
	return $self->{mfd1}[2][9];
    } else {
	# MFD1/MFD2 blocks
	if (defined($new)) {
	    # new data and indicate changed
	    $self->{mfd1}[2][1] = $new;
	    $self->{mfd1}[1] = 1;
	}
	return $self->{mfd1}[2][1];
    }
}

#----------------------------------------------------------------------------------------------------

# UFD entry length (words)

sub ufdlen {
    my ($self) = @_;
    return 9;
}

#----------------------------------------------------------------------------------------------------

# MAP entry length (words)

sub maplen {
    my ($self) = @_;
    return 60;
}

#----------------------------------------------------------------------------------------------------

# ptr to first MONITOR block

sub monblk {
    my ($self,$new) = @_;
    if ($self->mfdnxt == 0) {
	# MFD1/2 block
	if (defined($new)) {
	    # new data and indicate changed
	    $self->{mfd1}[2][11] = $new;
	    $self->{mfd1}[1] = 1;
	}
	return $self->{mfd1}[2][11];
    } else {
	# MFD1/MFD2 blocks ... return position from database
	return $db{$self->{device}}{MON}->[0];
    }
}

#----------------------------------------------------------------------------------------------------

# number of supported blocks

sub supnum {
    my ($self,$new) = @_;
    if ($self->mfdnxt == 0) {
	# MFD1/2 block
	if (defined($new)) {
	    # new data and indicate changed
	    $self->{mfd1}[2][7] = $new;
	    $self->{mfd1}[1] = 1;
	}
	return $self->{mfd1}[2][7];
    } else {
	# MFD1/MFD2 blocks
	$self->{_supnum} = $new if defined($new);
	return $self->{_supnum};
    }
}

#----------------------------------------------------------------------------------------------------

# number of preallocated blocks

sub prenum {
    my ($self,$new) = @_;
    if ($self->mfdnxt == 0) {
	# MFD1/2 block
	if (defined($new)) {
	    # new data and indicate changed
	    $self->{mfd1}[2][8] = $new;
	    $self->{mfd1}[1] = 1;
	}
	return $self->{mfd1}[2][8];
    } else {
	# MFD1/MFD2 blocks
	return undef;
    }
}

#----------------------------------------------------------------------------------------------------

# number of UFD blocks

sub ufdnum {
    my ($self,$new) = @_;
    $self->{_ufdnum} = $new if defined($new);
    return $self->{_ufdnum};
}

#----------------------------------------------------------------------------------------------------

# number of MAP blocks

sub mapnum {
    my ($self,$new) = @_;
    $self->{_mapnum} = $new if defined($new);
    return $self->{_mapnum};
}

#----------------------------------------------------------------------------------------------------

# number of USED blocks

sub usenum {
    my ($self,$new) = @_;
    $self->{_usenum} = $new if defined($new);
    return $self->{_usenum};
}

#----------------------------------------------------------------------------------------------------

# number of ACTUAL blocks, based on file size

sub actnum {
    my ($self) = @_;
    return int($self->{bytes}/(2*$self->{blklen}));
}

#----------------------------------------------------------------------------------------------------

# number of UFD entries

sub ufdentrynum {
    my ($self) = @_;
    my $entriesperufd = int($self->{blklen}/$self->ufdlen);	# number of UFD entries per block
    return $entriesperufd*$self->ufdnum;			# total number of UFD entries
}

#----------------------------------------------------------------------------------------------------

# UFD entry 1..N

sub ufdentry {
    my ($self,$num,@new) = @_;
    my $entriesperufd = int($self->{blklen}/$self->ufdlen);	# number of UFD entries per block
    my $idx = 1 + int(($num-1)/$entriesperufd);			# which UFD block
    my $ufd = @{$self->{ufd}{$idx}}[2];				# retrieve UFD block ref
    my $offset = 1 + $self->ufdlen*(($num-1) % $entriesperufd);	# which UFD entry in the block
    if (scalar(@new) == $self->ufdlen) {			# new value supplied?
	@{$self->{ufd}{$idx}}[1] = 1;				# indicate UFD block changed
	splice(@$ufd, $offset, $self->ufdlen, @new);		# insert new UFD entry
    }								#
    my @entry = @$ufd[$offset..($offset+$self->ufdlen-1)];	# extract old UFD entry
    return wantarray ? @entry : [@entry];			# return to caller
}

#----------------------------------------------------------------------------------------------------

# find first empty UFD entry 1..N, else return 0 if none

sub ufdfree {
    my ($self) = @_;
    for (my $i = 1; $i <= $self->ufdentrynum; ++$i) {		# iterate over all UFD entries
	my ($file1,$file2,$extn) = $self->ufdentry($i);		# get elements of current UFD entry
	return $i if $file1 == 0 && $file2 == 0 && $extn == 0;	# return first unused directory entry
    }								#
    return -1;							# no empty entries
}

#----------------------------------------------------------------------------------------------------

# MAP entry 0..N-1

sub mapentry {
    my ($self,$num,$new) = @_;
    return 0 if $num >= $self->supnum;				# block number too high
    my $bitsperentry = 16;					# number of bits per MAP word
    my $blockspermap = $bitsperentry*$self->maplen;		# number of MAP'ed blocks per MAP
    my $idx = 1 + int($num/$blockspermap);			# which MAP block
    return 0 if $idx > $self->mapnum;				# block number too high
    my $map = @{$self->{map}{$idx}}[2];				# retrieve MAP block ref
    my $offset = 4 + int(($num % $blockspermap)/$bitsperentry);	# which MAP word in the block
    my $old = 0x1 & (@$map[$offset] >> ($num % $bitsperentry));	# old map bit value
    if (defined($new)) {					# new value supplied?
	$new &= 0x1;						# mask to one bit
	if ($old != $new) {					# map bit changed?
	    @{$self->{map}{$idx}}[1] = 1;			# indicate map block changed
	    my $bit = 1 << ($num % $bitsperentry);		# the bit we are tweaking
	    if ($new == 1) {					# setting the bit?
		@$map[$offset] |= $bit;				# insert one value
		$self->usenum($self->usenum+1);			# one more used block
	    } else {						#
		@$map[$offset] &= ~$bit;			# insert zero value
		$self->usenum($self->usenum-1);			# one less used block
	    }							#
	    $old = $new;					# and set values equal
	}							#
    }								#
    return $old;						# return map bit to caller
}

#----------------------------------------------------------------------------------------------------

# find first empty MAP entry (ie, unused block) 1..N, else return 0 if none

sub mapfree {
    my ($self,$num) = @_;
    for (my $blk = $num; $blk < $self->supnum; ++$blk) {	# loop over all blocks
	return $blk if $self->mapentry($blk) == 0;		# return on unused block
    }								#
    return 0;							# no free blocks
}

#----------------------------------------------------------------------------------------------------

# initialize data structures to default values

sub default {

    my ($self) = @_;

    # initialize data structures
    $self->{blklen} = 256;		# number of words per logical block

    $self->{disk} = undef;		# file handle of disk image
    $self->{path} = '.';		# path for file insert/extract
    $self->{image} = undef;		# file name of disk image
    $self->{device} = 'NONE';		# device code name string

    $self->{mfd1} = ();			# MFD1 or MFD1/2 block
    $self->{mfd2} = ();			# MFD2 block
    $self->{map} = ();			# bitmap blocks
    $self->{ufd} = ();			# directory blocks

    foreach my $key (keys(%{$self})) {
	$self->{$key} = undef if $key =~ m/^_/; # undef _xxx names
    }

    return;
}

#----------------------------------------------------------------------------------------------------

# read a logical block from the device
#
# return the block as an array of 16.bit words
#
# warn with an error message on any read failure

sub readblk {

    my ($self,$blknum) = @_;

    my $disk = $self->{disk};					# filehandle to read from
    my $device = exists($xl{$self->{device}}) ? $xl{$self->{device}} : $self->{device};
    my @buf = ();						# unpack to here

    if ($device eq 'RX01' || $device eq 'RX02') {

	# implement the DEC standard 2:1 interleave used on the RX series drive

	my $spt = $rxdb{$device}{SPT};				# number of sectors per track
	my $nwc = $rxdb{$device}{WPS};				# number of words per sector
	my $nbc = $rxdb{$device}{BPS};				# number of bytes per sector
	my $spb = int($self->{blklen} / $nwc);			# number of sectors per block

	for (my $i = 0; $i < $spb; ++$i) {			# iterate over each sector per block

	    my $lsn = $blknum * $spb + $i;			# logical sector number within block
	    my $trk = int($lsn / $spt);				# logical track number
	    my $sec = $lsn % $spt;				# logical sector number
	    $sec = (2*$sec + (2*$sec >= $spt ? 1 : 0)) % $spt;	# make 2:1 sector interleave
	    $sec = 1 + ($sec + 6*$trk) % $spt;			# and 6 sector track-track offset
	    $trk = 1 + $trk;					# skip track zero

	    my $pos = ($spt*$trk + ($sec-1))*$nbc;		# byte seek position of the block
	    my $buf = undef;					# read to here

	    printf STDERR "readblk:  blknum=%-4d nbc=%d spb=%d lsn=%-4d i=%d trk=%-2d sec=%-2d pos=%d\n",
	                  $blknum, $nbc, $spb, $lsn, $i, $trk, $sec, $pos if $self->{DEBUG} >= 3;

	    warn sprintf("read seek error %d",$pos) unless sysseek($disk, $pos, 0) == $pos; # seek to desired block
	    my $cnt = sysread($disk, $buf, $nbc);		# do the read
	    warn sprintf("read data error %d <> %d",$cnt,$nbc) unless $cnt == $nbc; # warn if can't read all we want
	    push(@buf, unpack(sprintf("v[%d]",$nwc), $buf));	# unpack into a word array

	}

    } else {

	# all other devices are 1:1 block mapping

	my $nwc = $self->{blklen};				# number of words to read
	my $nbc = 2*$nwc;					# number of bytes to read
	my $pos = $blknum*$nbc;					# byte seek position of the block
	my $buf = undef;					# read to here

	warn sprintf("read seek error %d",$pos) unless sysseek($disk, $pos, 0) == $pos; # seek to desired block
	my $cnt = sysread($disk, $buf, $nbc);			# do the read
	warn sprintf("read data error %d <> %d",$cnt,$nbc) unless $cnt == $nbc; # warn if can't read all we want
	push(@buf, unpack(sprintf("v[%d]",$nwc), $buf));	# unpack into a word array

    }

    if ($self->{DEBUG} >= 4) {
	my $chars;
	for (my $i = 0; $i <= $#buf; ++$i) {
	    printf STDERR "%06o:", $blknum if $i == 0;
	    if ($i % 8 == 0 && $i > 0) { printf STDERR "       "; $chars = ""; }
	    printf STDERR " %06o", $buf[$i];
	    $chars .= &_mapchr($buf[$i]) . &_mapchr($buf[$i]>>8);
	    printf STDERR " %s\n", $chars if $i % 8 == 7;
	}
    }

    return wantarray ? @buf : [@buf];
}

#----------------------------------------------------------------------------------------------------

# write a logical block to the device from an array of 16.bit words
#
# returns nothing
#
# warn with an error message on any write failure

sub writeblk {

    my ($self,$blknum,$dat) = @_;

    my $disk = $self->{disk};					# filehandle to write to
    my $device = exists($xl{$self->{device}}) ? $xl{$self->{device}} : $self->{device};
    my @buf = @$dat;						# retrieve data into an array

    while (scalar(@buf) < $self->{blklen}) { push(@buf, 0); }	# zero extend to block length

    warn sprintf("write length error: %d <> %d",scalar(@buf),$self->{blklen})
	unless scalar(@buf) == $self->{blklen}; # must be exactly one block worth of data

    if ($device eq 'RX01' || $device eq 'RX02') {

	# implement the DEC standard 2:1 interleave used on the RX series drive

	my $spt = $rxdb{$device}{SPT};				# number of sectors per track
	my $nwc = $rxdb{$device}{WPS};				# number of words per sector
	my $nbc = $rxdb{$device}{BPS};				# number of bytes per sector
	my $spb = int($self->{blklen} / $nwc);			# number of sectors per block

	for (my $i = 0; $i < $spb; ++$i) {			# iterate over each sector per block

	    my $lsn = $blknum * $spb + $i;			# logical sector number within block
	    my $trk = int($lsn / $spt);				# logical track number
	    my $sec = $lsn % $spt;				# logical sector number
	    $sec = (2*$sec + (2*$sec >= $spt ? 1 : 0)) % $spt;	# make 2:1 sector interleave
	    $sec = 1 + ($sec + 6*$trk) % $spt;			# and 6 sector track-track offset
	    $trk = 1 + $trk;					# skip track zero

	    my $pos = ($spt*$trk + ($sec-1))*$nbc;		# byte seek position of the block
	    my $buf = pack(sprintf("v[%d]",$nwc), splice(@buf,0,$nwc));	# pack word array into the buffer

	    printf STDERR "writeblk: blknum=%-4d nbc=%d spb=%d lsn=%-4d i=%d trk=%-2d sec=%-2d pos=%d\n",
	                  $blknum, $nbc, $spb, $lsn, $i, $trk, $sec, $pos if $self->{DEBUG} >= 3;

	    warn sprintf("write seek error %d",$pos) unless sysseek($disk, $pos, 0) == $pos; # seek to desired block
	    my $cnt = syswrite($disk, $buf);			# do the write
	    warn sprintf("write data error %d <> %d",$cnt,$nbc) unless $cnt == $nbc; # warn if can't write all we want

	}

    } else {

	# all other devices are 1:1 block mapping

	my $nwc = $self->{blklen};				# number of words to write
	my $nbc = 2*$nwc;					# number of bytes to write
	my $pos = $blknum*$nbc;					# byte seek position of the block
	my $buf = pack(sprintf("v[%d]",$nwc), @buf);		# pack word array into the buffer

	warn sprintf("write seek error %d",$pos) unless sysseek($disk, $pos, 0) == $pos; # seek to desired block
	my $cnt = syswrite($disk, $buf);			# do the write
	warn sprintf("write data error %d <> %d",$cnt,$nbc) unless $cnt == $nbc; # warn if can't write all we want

    }

    if ($self->{DEBUG} >= 4) {
	my $chars;
	for (my $i = 0; $i <= $#buf; ++$i) {
	    printf STDERR "%06o:", $blknum if $i == 0;
	    if ($i % 8 == 0 && $i > 0) { printf STDERR "       "; $chars = ""; }
	    printf STDERR " %06o", $buf[$i];
	    $chars .= &_mapchr($buf[$i]) . &_mapchr($buf[$i]>>8);
	    printf STDERR " %s\n", $chars if $i % 8 == 7;
	}
    }

    return;
}

#----------------------------------------------------------------------------------------------------
#
# P R I V A T E   R o u t i n e s
#
#----------------------------------------------------------------------------------------------------

# strip all whitespace in a string

sub _strp {

    my ($str) = @_;

    $str =~ s/\s+//g;

    return $str;
}

#----------------------------------------------------------------------------------------------------

# determine if a file name / extension matches a pattern

sub _file_matches {

    my ($pattern,@filepart) = @_;

    # convert the pattern characters to a perl regexp
    $pattern =~ s/[.]/[.]/g;            # change . to [.]
    $pattern =~ s/[*]/[A-Z0-9\$\.%]*/g; # change * to match [A-Z0-9$.%]{1,}
    $pattern =~ s/[?]/[A-Z0-9\$\.%]/g;  # change ? to match [A-Z0-9$.%]{1}

    # file name.extn, minus spaces
    my $full = &_strp(join('.',@filepart));

    # return matching status
    return $full =~ m/^${pattern}$/i;
}

#----------------------------------------------------------------------------------------------------

# count all the one bit(s) in the arg(s)

sub _countones {

    my $ones = 0;

    # count all the ones in all the arguments
    foreach my $arg (@_) { my $copy = $arg; do { $ones++ if $copy & 1; } while ($copy >>= 1); }

    return $ones;
}

#----------------------------------------------------------------------------------------------------

# map a char to itself if printable, else make it a dot

sub _mapchr {

    my ($d) = @_;

    $d &= 0xFF; # mask to 8 bits
    return chr($d) if $d >= ord(' ') && $d <= ord('~'); # printable
    return '.'; # not printable
}

#----------------------------------------------------------------------------------------------------

# ASCII date to DOS11 date encode

sub _asc2date {

    my ($ascii) = @_;

    # extract day-of-month, month, and year
    my ($dom,$mon,$year) = (uc($ascii) =~ m/^\s*(\d+)\s*-\s*([A-Z]+)\s*-\s*(\d+)\s*$/);

    # correct year for various formats
    $year += 2000 if $year <= 69; # 00..69 => 2000..2069
    $year += 1900 if $year <= 99; # 70..99 => 1970..1999
    $year  = 1999 if $year >= 2000; # display max is '99'

    # table of day-of-year offsets per month
    my %doy = (JAN=>0,   FEB=>31,  MAR=>59,
	       APR=>90,  MAY=>120, JUN=>151,
	       JUL=>181, AUG=>212, SEP=>243,
	       OCT=>273, NOV=>304, DEC=>334);

    # correct for leap year
    my $leap = &_isleapyear($year) && $doy{$mon} >= 59 ? 1 : 0;

    # return encoded DOS11 date word
    return ($year-1970)*1000 + $doy{$mon} + $dom + $leap;
}

#----------------------------------------------------------------------------------------------------

# DOS11 date to ASCII date decode

sub _date2asc {

    my ($date) = @_;

    my $data = $date & 077777;	     # low 15.bits only
    my $year = int($data/1000)+1970; # encoded year
    my $doy = $data%1000;            # encoded day of year

    my @dpm = (31,28,31, 30,31,30, 31,31,30, 31,30,31); # days per month
    my @mon = ('JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'); # names
    $dpm[1]++ if &_isleapyear($year);                   # fixup leap years
    
    # turn day-of-year into day-of-month and month-of-year
    my $mon = 0; while ($mon <= $#mon) { last if $doy <= $dpm[$mon]; $doy -= $dpm[$mon++]; }

    # return an ascii date string
    return sprintf("%2d-%3s-%02d", $doy,$mon[$mon],$year-1900);
}

#----------------------------------------------------------------------------------------------------

# DOS11 date to unix timestamp decode

sub _date2stamp {

    my ($date) = @_;

    my $data = $date%32768;	     # low 15.bits only
    my $year = int($data/1000)+1970; # encoded year
    my $doy = $data%1000;            # encoded day of year

    my @dpm = (31,28,31, 30,31,30, 31,31,30, 31,30,31); # days per month
    my @mon = ('JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'); # names
    $dpm[1]++ if &_isleapyear($year);                   # fixup leap years
    
    # turn day-of-year into day-of-month and month-of-year
    my $mon = 0; while ($mon <= $#mon) { last if $doy <= $dpm[$mon]; $doy -= $dpm[$mon++]; }

    # range check day
    $doy = 1 if $doy < 1;
    $doy = $dpm[$mon] if $doy > $dpm[$mon];

    # return a system timestamp as 12 noon on the given date
    return timelocal(0,0,12, $doy,$mon,$year);
}

#----------------------------------------------------------------------------------------------------

# RAD50 to ASCII decode

sub _rad2asc {

    my @str = split(//, ' ABCDEFGHIJKLMNOPQRSTUVWXYZ$.%0123456789'); # RAD50 character subset

    my $ascii = "";
    foreach my $rad50 (@_) {
	$ascii .= $str[int($rad50/1600)%40] . $str[int($rad50/40)%40] . $str[$rad50%40];
    }

    return $ascii;
}

#----------------------------------------------------------------------------------------------------

# ASCII to RAD50 encode

sub _asc2rad {

    my ($ascii) = @_;

    my $str = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ$.%0123456789'; # missing char's get mapped to ' ' (zero)

    my @rad50 = ();
    $ascii .= ' ' until length($ascii)%3 == 0 && length($ascii) > 0;
    $ascii = uc($ascii);
    for (my $i = 0; $i < length($ascii); $i += 3) {
	push(@rad50, 1600*index($str,substr($ascii,$i+0,1))
	             + 40*index($str,substr($ascii,$i+1,1))
	             +  1*index($str,substr($ascii,$i+2,1)) + 1641);
    }

    return wantarray ? @rad50 : @rad50==1 ? $rad50[0] : [@rad50];
}

#----------------------------------------------------------------------------------------------------

# leap year routine

sub _isleapyear {

    my ($year) = @_;

    return (($year % 4 == 0) && ($year % 100 != 0)) || ($year % 400 == 0);
}

#----------------------------------------------------------------------------------------------------

1;

# the end
