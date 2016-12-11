<B>xxdpdir.pl</B> and associated module <B>XXDP.pm</B> is a DEC PDP-11 XXDP (DOS-11) file system manipulation program. Using this program XXDP file system images (as used by DEC PDP-11 diagnostics) can be created and listed, and files extracted/inserted from/to file system images.

Once created, these file system image files can be used with the SIMH PDP-11 hardware simulator environment, can be copied to legacy hardware (ie, real RL02 media, RX02 media, etc), can be used with peripheral emulators (ie, TU58EM TU58 drive emulator, RX02 emulator, SCSI2SD SCSI disk emulator).

At present creating and manipulating images for the following devices is supported:

```
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

Image size listed is total image file size; blocks allocated to actual storage may be slightly smaller.
```

The functionality is loosely modeled after the command line arguments of the legacy DOS xxdpdir/diagdir programs.

If run with no options, it prints a usage screen:

```
xxdpdir.pl v1.0 by Don North (perl 5.022)
Usage: ./xxdpdir.pl [options...] arguments...
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
Aborted due to command line errors.
```

If run with the --help option it prints a longer manual page:

```
NAME
    xxdpdir.pl - Manipulate XXDP/DOS11 Disk Image Files

SYNOPSIS
    xxdpdir.pl [--help] [--warn] [--debug=N] [--verbose] [--dump]
    [--device=NAME] [--format=TYPE] [--path=FOLDER] [--initialize]
    [--extract(=PATTERN)] [--delete(=PATTERN)] [--insert(=PATTERN)]
    [--directory(=PATTERN)] [--bootable(=PATTERN)] --image=FILENAME

DESCRIPTION
    xxdpdir.pl and associated module XXDP.pm is a DEC PDP-11 XXDP (DOS-11)
    file system manipulation program. Using this program XXDP file system
    images (as used by DEC PDP-11 diagnostics) can be created and listed, and
    files extracted/inserted from/to file system images.

    Once created, these file system image files can be used with the SIMH
    PDP-11 hardware simulator environment, can be copied to legacy hardware
    (ie, real RL02 media, RX02 media, etc), can be used with peripheral
    emulators (ie, TU58EM TU58 drive emulator, RX02 emulator, SCSI2SD SCSI
    disk emulator).

OPTIONS
    The following options are available:

    --help
        Output this manpage and exit the program.

    --warn
        Enable warnings mode.

    --debug=N
        Enable debug mode at level N (0..5 are defined). Higher number
        indicates more verbose output.

    --verbose
        Verbose status output.

    --device=NAME
        Disk device id string (e.g. TU58, RX02) being manipulated. Required
        when using --initialize to indicate the image type being created.
        Usually optional on created filesystems (as an initialized image has
        on disk structures that describe the volume) EXCEPT for RX01 and RX02
        media types. When manipulating RX01 or RX02 media ALWAYS supply the
        --device=NAME option because you need to inform the program about the
        low level format of the image (ie, track 0 skipped; sector interleave
        factor).

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

    --image=FILENAME
        Name of the .dsk image to manipulated. Required.

        In most instances a file extension of .DSK (or anything; really does
        not matter) is sufficient. However, there are two special cases: a
        file extension of .RX1/.RX01 (for RX01) and .RX2/.RX02 (for RX02) will
        supply a default value for the --device switch, if is is not otherwise
        explicitly supplied.

    --path=FOLDER
        Path to extract/insert file folder, default is '.'.

    --initialize
        Initialize disk device to empty file structure with no files present.

    --extract(=PATTERN)
        Extract files that match the pattern, default '*.*'. Multiple
        instances OK. Files will be extracted to the folder indicated by
        --path=NAME.

    --delete(=PATTERN)
        Delete files that match the pattern, default '*.*'. Multiple instances
        OK.

    --insert(=PATTERN)
        Insert files that match the pattern, default '*.*'. Multiple instances
        OK. Files will be inserted from the folder indicated by --path=NAME.

    --directory(=PATTERN)
        List a directory of files matching the pattern, default '*.*'.
        Multiple instances OK. Format will be as specified by the
        --format=TYPE option.

    --bootable(=PATTERN)
        Write the boot block and monitor image from the disk resident monitor
        image (XXDPSM.SYS) and the appropriate device driver file (e.g.
        DY.SYS, DD.SYS, DU.SYS, etc).

    --format=TYPE
        Directory listing format: 'diagdir', 'xxdp', 'extended', or 'standard'
        (default)

    --dump
        Formatted dump of all on disk data structures (used for debugging;
        lots of output).

PATTERNS
    The pattern argument supplied to the
    insert/extract/delete/directory/bootable switches can be in the following
    formats (this is basically the legacy DEC file selection method):

        FILE.EXT - a single full filename
        *.EXT    - wildcard filename, given extension
        FILE.*   - given filename, wildcard extension
        *.*      - wildcard filename and extension
        X?.YYY   - wilcard single character replacement
        X??.YY?  - other variations possible

    Filenames in XXDP filesystems are in a 6.3 format (i.e. six character
    filename, maximum; three character file extension, maximum). The character
    set is limited to: A..Z 0..9 $%

NOTE
    Multiple action switches (initialize, extract, delete, insert, directory,
    bootable) are possible within one command invocation. The order of
    operations is as follows:

        (1) initialize - create a new empty file structure
        (2) extract - extract files matching pattern
        (3) delete - delete files matching pattern
        (4) insert - insert files matching pattern
        (5) directory - list files matching pattern
        (6) bootable - write monitor/boot blocks

EXAMPLES
    Some examples of common usage:

      xxdpdir.pl --help

      xxdpdir.pl --image=image.dsk --directory > listing.txt

      xxdpdir.pl --image=image.dsk --path=srcfiles --device=TU58 --init --insert=*.SYS --bootable

      xxdpdir.pl --image=image.rx2 --init --insert=*.SYS --bootable --directory > files.lst

AUTHOR
    Don North - donorth <ak6dn _at_ mindspring _dot_ com>

HISTORY
    Modification history:

      2016-11-01 v1.0 donorth - Initial version..

```

Here is an example run of creating an RX02 bootable XXDP image file:

+ rm -f rx02.dsk
+ xxdpdir.pl --verbose --image rx02.dsk --device RX02 --path tmp --ins 'xxdp??.sys' --init
Insert:     1:  XXDPSM.SYS   1-MAR-89    29 blocks start    55 end    83
Insert:     2:  XXDPXM.SYS   1-MAR-89    39 blocks start    84 end   122
Inserted 2 files
+ xxdpdir.pl --verbose --image rx02.dsk --device RX02 --path tmp --ins 'drs??.sys'
Insert:     3:  DRSSM .SYS   1-MAR-89    24 blocks start   123 end   146
Insert:     4:  DRSXM .SYS   1-MAR-89    48 blocks start   147 end   194
Inserted 2 files
+ xxdpdir.pl --verbose --image rx02.dsk --device RX02 --path tmp --ins date.sys
Insert:     5:  DATE  .SYS   1-MAR-89     2 blocks start   195 end   196
Inserted 1 files
+ xxdpdir.pl --verbose --image rx02.dsk --device RX02 --path tmp --ins db.sys
Insert:     6:  DB    .SYS   1-MAR-89     2 blocks start   197 end   198
Inserted 1 files
+ xxdpdir.pl --verbose --image rx02.dsk --device RX02 --path tmp --ins dd.sys
Insert:     7:  DD    .SYS   1-MAR-89     3 blocks start   199 end   201
Inserted 1 files
+ xxdpdir.pl --verbose --image rx02.dsk --device RX02 --path tmp --ins dir.sys
Insert:     8:  DIR   .SYS   1-MAR-89     7 blocks start   202 end   208
Inserted 1 files
+ xxdpdir.pl --verbose --image rx02.dsk --device RX02 --path tmp --ins dl.sys
Insert:     9:  DL    .SYS   1-MAR-89     4 blocks start   209 end   212
Inserted 1 files
+ xxdpdir.pl --verbose --image rx02.dsk --device RX02 --path tmp --ins dm.sys
Insert:    10:  DM    .SYS   1-MAR-89     4 blocks start   213 end   216
Inserted 1 files
+ xxdpdir.pl --verbose --image rx02.dsk --device RX02 --path tmp --ins dr.sys
Insert:    11:  DR    .SYS   1-MAR-89     3 blocks start   217 end   219
Inserted 1 files
+ xxdpdir.pl --verbose --image rx02.dsk --device RX02 --path tmp --ins du.sys
Insert:    12:  DU    .SYS   1-MAR-89     4 blocks start   220 end   223
Inserted 1 files
+ xxdpdir.pl --verbose --image rx02.dsk --device RX02 --path tmp --ins dusz.sys
Insert:    13:  DUSZ  .SYS   1-MAR-89     2 blocks start   224 end   225
Inserted 1 files
+ xxdpdir.pl --verbose --image rx02.dsk --device RX02 --path tmp --ins dy.sys
Insert:    14:  DY    .SYS   1-MAR-89     3 blocks start   226 end   228
Inserted 1 files
+ xxdpdir.pl --verbose --image rx02.dsk --device RX02 --path tmp --ins 'l*.sys' --ins 'm*.sys'
Insert:    15:  LP    .SYS   1-MAR-89     1 blocks start   229 end   229
Insert:    16:  MM    .SYS   1-MAR-89     3 blocks start   230 end   232
Insert:    17:  MS    .SYS   1-MAR-89     4 blocks start   233 end   236
Insert:    18:  MU    .SYS   1-MAR-89     4 blocks start   237 end   240
Inserted 4 files
+ xxdpdir.pl --verbose --image rx02.dsk --device RX02 --path tmp --ins '*.txt'
Insert:    19:  HELP  .TXT   1-MAR-89    29 blocks start   241 end   269
Inserted 1 files
+ xxdpdir.pl --verbose --image rx02.dsk --device RX02 --path tmp --ins '*.bic'
Insert:    20:  PATCH .BIC   1-MAR-89    31 blocks start   270 end   300
Insert:    21:  SETUP .BIC   1-MAR-89    27 blocks start   301 end   327
Insert:    22:  UPDAT .BIC   1-MAR-89    29 blocks start   328 end   356
Insert:    23:  XTECO .BIC   1-MAR-89    26 blocks start   357 end   382
Inserted 4 files
+ xxdpdir.pl --verbose --image rx02.dsk --device RX02 --path tmp --ins '*.bin' --boot
Insert:    24:  FLOAT .BIN   1-MAR-89    18 blocks start   383 end   400
Inserted 1 files
Boot and monitor blocks written from file(s): XXDPSM.SYS, DY.SYS
+ xxdpdir.pl --verbose --image rx02.dsk --device RX02 --path tmp --dir
DOS11 format, assume monitor starts at block 23
Image supports 1001 blocks
16 directory blocks, block 3 thru 18
4 bitmap blocks, block 19 thru 22
401 device blocks in use according to the bitmap

ENTRY# FILNAM.EXT        DATE          LENGTH  START   VERSION

    1  XXDPSM.SYS       1-MAR-89          29     55     E.0
    2  XXDPXM.SYS       1-MAR-89          39     84     F.0
    3  DRSSM .SYS       1-MAR-89          24    123     G.2
    4  DRSXM .SYS       1-MAR-89          48    147     C.0
    5  DATE  .SYS       1-MAR-89           2    195     B.0
    6  DB    .SYS       1-MAR-89           2    197     C.0
    7  DD    .SYS       1-MAR-89           3    199     D.0
    8  DIR   .SYS       1-MAR-89           7    202     D.0
    9  DL    .SYS       1-MAR-89           4    209     D.0
   10  DM    .SYS       1-MAR-89           4    213     C.0
   11  DR    .SYS       1-MAR-89           3    217     C.0
   12  DU    .SYS       1-MAR-89           4    220     E.0
   13  DUSZ  .SYS       1-MAR-89           2    224     C.0
   14  DY    .SYS       1-MAR-89           3    226     D.0
   15  LP    .SYS       1-MAR-89           1    229     B.0
   16  MM    .SYS       1-MAR-89           3    230     C.0
   17  MS    .SYS       1-MAR-89           4    233     C.0
   18  MU    .SYS       1-MAR-89           4    237     E.0
   19  HELP  .TXT       1-MAR-89          29    241
   20  PATCH .BIC       1-MAR-89          31    270
   21  SETUP .BIC       1-MAR-89          27    301
   22  UPDAT .BIC       1-MAR-89          29    328
   23  XTECO .BIC       1-MAR-89          26    357
   24  FLOAT .BIN       1-MAR-89          18    383

FREE BLOCKS:   600
```
