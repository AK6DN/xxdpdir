#!/usr/bin/perl -w
#!/usr/local/bin/perl -w

# Copyright (c) 2016 Don North
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 
# o Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# 
# o Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
# 
# o Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
# TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require 5.008;

=head1 NAME

xxdpdir.pl - Manipulate XXDP/DOS11 Disk Image Files

=head1 SYNOPSIS

xxdpdir.pl
S<[--help]>
S<[--warn]>
S<[--debug=N]>
S<[--verbose]>
S<[--dump]>
S<[--device=NAME]>
S<[--format=TYPE]>
S<[--path=FOLDER]>
S<[--initialize]>
S<[--extract(=PATTERN)]>
S<[--delete(=PATTERN)]>
S<[--insert(=PATTERN)]>
S<[--directory(=PATTERN)]>
S<[--bootable(=PATTERN)]>
S<--image=FILENAME>

=head1 DESCRIPTION

B<xxdpdir.pl> and associated module B<XXDP.pm> is a DEC PDP-11 XXDP (DOS-11) file system manipulation program.
Using this program XXDP file system images (as used by DEC PDP-11 diagnostics) can be created and listed, and
files extracted/inserted from/to file system images.

Once created, these file system image files can be used with the SIMH PDP-11 hardware simulator environment,
can be copied to legacy hardware (ie, real RL02 media, RX02 media, etc), can be used with peripheral emulators
(ie, TU58EM TU58 drive emulator, RX02 emulator, SCSI2SD SCSI disk emulator).

=head1 OPTIONS

The following options are available:

=over

=item B<--help>

Output this manpage and exit the program.

=item B<--warn>

Enable warnings mode.

=item B<--debug=N>

Enable debug mode at level N (0..5 are defined). Higher number indicates more verbose output.

=item B<--verbose>

Verbose status output.

=item B<--device=NAME>

Disk device id string (e.g. TU58, RX02) being manipulated. Required when using S<--initialize> to
indicate the image type being created. Usually optional on created filesystems (as an initialized
image has on disk structures that describe the volume) EXCEPT for RX01 and RX02 media types. When
manipulating RX01 or RX02 media ALWAYS supply the S<--device=NAME> option because you need to inform
the program about the low level format of the image (ie, track 0 skipped; sector interleave factor).

The following device types are currently supported:
    
    RX01 -    256,256 bytes, physical 1:1 sector image
    RX02 -    512,512 bytes, physical 1:1 sector image
    TU58 -    262,144 bytes, logical block image
    RL01 -  5,242,880 bytes, logical block image (incl DEC BAD144 area)
    RL02 - 10,485,760 bytes, logical block image (incl DEC BAD144 area)
    RK06 - 13,888,512 bytes, logical block image (incl DEC BAD144 area)
    RK07 - 27,540,480 bytes, logical block image (incl DEC BAD144 area)
    RM03 - 24,576,000 bytes, logical block image
    RP04 - 24,576,000 bytes, logical block image
    MSCP - 33,553,920 bytes, logical block image

=item B<--image=FILENAME>

Name of the .dsk image to manipulated. Required.

In most instances a file extension of .DSK (or anything; really does not matter) is sufficient.
However, there are two special cases: a file extension of .RX1/.RX01 (for RX01) and .RX2/.RX02 (for RX02)
will supply a default value for the S<--device> switch, if is is not otherwise explicitly supplied.

=item B<--path=FOLDER>

Path to extract/insert file folder, default is '.'.

=item B<--initialize>

Initialize disk device to empty file structure with no files present.

=item B<--extract(=PATTERN)>

Extract files that match the pattern, default '*.*'. Multiple instances OK.
Files will be extracted to the folder indicated by S<--path=NAME>.

=item B<--delete(=PATTERN)>

Delete files that match the pattern, default '*.*'. Multiple instances OK.

=item B<--insert(=PATTERN)>

Insert files that match the pattern, default '*.*'. Multiple instances OK.
Files will be inserted from the folder indicated by S<--path=NAME>.

=item B<--directory(=PATTERN)>

List a directory of files matching the pattern, default '*.*'. Multiple instances OK.
Format will be as specified by the S<--format=TYPE> option.

=item B<--bootable(=PATTERN)>

Write the boot block and monitor image from the disk resident monitor image (XXDPSM.SYS)
and the appropriate device driver file (e.g. DY.SYS, DD.SYS, DU.SYS, etc).

=item B<--format=TYPE>

Directory listing format: 'diagdir', 'xxdp', 'extended', or 'standard' (default)

=item B<--dump>

Formatted dump of all on disk data structures (used for debugging; lots of output).

=back

=head1 PATTERNS

The pattern argument supplied to the insert/extract/delete/directory/bootable switches can
be in the following formats (this is basically the legacy DEC file selection method):

    FILE.EXT - a single full filename
    *.EXT    - wildcard filename, given extension
    FILE.*   - given filename, wildcard extension
    *.*      - wildcard filename and extension
    X?.YYY   - wilcard single character replacement
    X??.YY?  - other variations possible

Filenames in XXDP filesystems are in a 6.3 format (i.e. six character filename, maximum; three
character file extension, maximum). The character set is limited to:  A..Z 0..9 $%

=head1 NOTE

Multiple action switches (initialize, extract, delete, insert, directory, bootable) are possible
within one command invocation. The order of operations is as follows:

    (1) initialize - create a new empty file structure
    (2) extract - extract files matching pattern
    (3) delete - delete files matching pattern
    (4) insert - insert files matching pattern
    (5) directory - list files matching pattern
    (6) bootable - write monitor/boot blocks

=head1 EXAMPLES

Some examples of common usage:

  xxdpdir.pl --help

  xxdpdir.pl --image=image.dsk --directory > listing.txt

  xxdpdir.pl --image=image.dsk --path=srcfiles --device=TU58 --init --insert=*.SYS --bootable

  xxdpdir.pl --image=image.rx2 --init --insert=*.SYS --bootable --directory > files.lst

=head1 AUTHOR

Don North - donorth <ak6dn _at_ mindspring _dot_ com>

=head1 HISTORY

Modification history:

  2016-11-01 v1.0 donorth - Initial version..

=cut

# options
use strict;
	
# external standard modules
use Getopt::Long;
use Pod::Text;
use FindBin;

# external local modules search path
BEGIN { unshift(@INC, $FindBin::Bin);
        unshift(@INC, $ENV{PERL5LIB}) if defined($ENV{PERL5LIB}); # cygwin bugfix
        unshift(@INC, '.'); }

# external local modules
use XXDP;

# generic defaults
my $VERSION = 'v1.0'; # version of code
my $HELP = 0; # set to 1 for man page output
my $WARN = 0; # set to 1 for warning messages
my $DEBUG = 0; # set to 1 for debug messages
my $VERBOSE = 0; # set to 1 for verbose messages

# specific defaults
my $DUMP = 0; # set to 1 for data structure dump
my $DEVICE = 'NONE'; # 'RX02', 'TU58', etc; specify device
my $INIT = 0; # set to initialize to an empty device image
my @TEST = (); # for argument testing
my @BOOT = (); # write boot block and monitor area
my @INSERT = (); # file insert pattern match
my @DELETE = (); # file delete pattern match
my @EXTRACT = (); # file extract pattern match
my @DIRECTORY = (); # directory pattern match
my $PATH = '.'; # extract/insert path, optional
my $IMAGE = undef; # dsk file image, must be supplied
my $FORMAT = 'standard'; # or 'extended', 'xxdp' or 'diagdir' directory format

# process command line arguments
my $NOERROR = GetOptions( "help"        => \$HELP,
			  "warn!"       => \$WARN,
			  "debug:i"     => \$DEBUG,
			  "verbose!"    => \$VERBOSE,
			  "dump"        => \$DUMP,
			  "initialize"  => \$INIT,
			  "path=s"      => \$PATH,
			  "image=s"     => \$IMAGE,
			  "device=s"    => sub { $DEVICE = uc($_[1]); },
			  "format=s"    => sub { $FORMAT = uc($_[1]); },
			  "bootable:s"  => sub { push(@BOOT,     map(split(',',$_),map($_?$_:'XXDPSM.SYS',splice(@_,1)))); },
			  "extract:s"   => sub { push(@EXTRACT,  map(split(',',$_),map($_?$_:'*.*',       splice(@_,1)))); },
			  "delete:s"    => sub { push(@DELETE,   map(split(',',$_),map($_?$_:'*.*',       splice(@_,1)))); },
			  "insert:s"    => sub { push(@INSERT,   map(split(',',$_),map($_?$_:'*.*',       splice(@_,1)))); },
			  "directory:s" => sub { push(@DIRECTORY,map(split(',',$_),map($_?$_:'*.*',       splice(@_,1)))); },
			  "test:s"      => sub { push(@TEST,     map(split(',',$_),map($_?$_:'DEFAULT',   splice(@_,1)))); },
			  );

# init
$WARN = 1 if $DEBUG; # debug implies warning messages
$VERBOSE = 1 if $DEBUG; # debug implies verbose messages

# output the documentation
if ($HELP) {
    # output a man page if we can
    if (ref(Pod::Text->can('new')) eq 'CODE') {
        # try the new way if appears to exist
        my $parser = Pod::Text->new(sentence=>0, width=>78);
        printf STDOUT "\n"; $parser->parse_from_file($0);
    } else {
        # else must use the old way
        printf STDOUT "\n"; Pod::Text::pod2text(-78, $0);
    };
    exit(1);
}

#----------------------------------------------------------------------------------------------------

# autodetect device type RX0n from file extensions .rx1/.rx01/.rx2/.rx02
$DEVICE = 'RX01' if $DEVICE eq 'NONE' && defined($IMAGE) && $IMAGE =~ m/[.]rx0?1$/i;
$DEVICE = 'RX02' if $DEVICE eq 'NONE' && defined($IMAGE) && $IMAGE =~ m/[.]rx0?2$/i;

#----------------------------------------------------------------------------------------------------

# debug print all arguments
if ($DEBUG) {
    printf STDERR "Options: \n";
    printf STDERR "  --help\n" if $HELP;
    printf STDERR "  --%swarn\n", $WARN ? '' : 'no';
    printf STDERR "  --debug=%d\n", $DEBUG if $DEBUG;
    printf STDERR "  --verbose\n" if $VERBOSE;
    printf STDERR "  --dump\n" if $DUMP;
    printf STDERR "  --device='%s'\n", $DEVICE;
    printf STDERR "  --format='%s'\n", $FORMAT;
    printf STDERR "  --path='%s'\n", $PATH;
    printf STDERR "  --image='%s'\n", $IMAGE;
    printf STDERR "  --initialize\n" if $INIT;
    printf STDERR "  --extract='%s'\n", join(',',@EXTRACT) if @EXTRACT;
    printf STDERR "  --delete='%s'\n", join(',',@DELETE) if @DELETE;
    printf STDERR "  --insert='%s'\n", join(',',@INSERT) if @INSERT;
    printf STDERR "  --directory='%s'\n", join(',',@DIRECTORY) if @DIRECTORY;
    printf STDERR "  --bootable='%s'\n", join(',',@BOOT) if @BOOT;
    printf STDERR "  --test='%s'\n", join(',',@TEST) if @TEST;
}

# check for correct arguments present, print usage if errors
unless ($NOERROR
	&& scalar(@ARGV) == 0
	&& defined($IMAGE)
    ) {
    printf STDERR "xxdpdir.pl %s by Don North (perl %g)\n", $VERSION, $];
    print STDERR "Usage: $0 [options...] arguments...\n";
    print STDERR <<"EOF";
       --help                  output manpage and exit
       --warn                  enable warnings mode
       --debug=N               enable debug mode N
       --verbose               verbose status reporting
       --dump                  data structure dump at end
       --device=NAME           disk device id string; eg TU58, RX02, etc
       --format=TYPE           directory listing: 'diagdir', 'xxdp', 'extended', or 'standard' (default)
       --path=FOLDER           path to extract/insert folder, default '.'
       --image=FILENAME        name of the .dsk image to manipulate
       --initialize            initialize disk device to empty
       --extract(=PATTERN)     extract file pattern match, default *.* ; multiple OK
       --delete(=PATTERN)      delete file pattern match, default *.* ; multiple OK
       --insert(=PATTERN)      insert file pattern match, default *.* ; multiple OK
       --directory(=PATTERN)   directory pattern match, default *.* ; multiple OK
       --bootable(=PATTERN)    write boot block and monitor image, default XXDPSM.SYS
EOF
    # exit if errors...
    die "Aborted due to command line errors.\n";
}

#----------------------------------------------------------------------------------------------------

# setup a new device structure
my $dsk = XXDP->new( -warn    => $WARN,
		     -debug   => $DEBUG,
		     -verbose => $VERBOSE,
		     -image   => $IMAGE,
		     -path    => $PATH,
		     -device  => $DEVICE );

# (0) test arguments ... for debugging only
print $dsk->test(                     ) if @TEST;
print $dsk->test( -pattern => \@TEST  ) if @TEST;
print $dsk->test( -pattern => [@TEST] ) if @TEST;

# (1) initialize the device (just an empty file system) if requested
if ($INIT) { die sprintf("Unable to init file: %s",$IMAGE) unless $dsk->init == 0; }

# (2) open the device for access, fail if unable to do so
die sprintf("Unable to open file: %s",$IMAGE) unless $dsk->open == 0;

# (3) extract files, if requested
print $dsk->extract( -pattern => \@EXTRACT ) if @EXTRACT;

# (4) delete files, if requested
print $dsk->delete( -pattern => \@DELETE ) if @DELETE;

# (5) insert files, if requested
print $dsk->insert( -pattern => \@INSERT ) if @INSERT;

# (6) print a directory listing, if requested
print $dsk->directory( -pattern => \@DIRECTORY, -format => $FORMAT ) if @DIRECTORY;

# (7) write boot blocks and monitor image, if requested
print $dsk->boot( -pattern => \@BOOT ) if @BOOT;

# (8) generate an ascii dump of the file structure
print $dsk->dump if $DUMP;

# (9) done with the image, close it
die sprintf("Unable to close file: %s",$IMAGE) unless $dsk->close == 0;

# and done
exit;

#----------------------------------------------------------------------------------------------------

# the end
