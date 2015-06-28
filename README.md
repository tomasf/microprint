# microprint
#### Printing software for M3D Micro for OS X

MicroPrint is a command-line program for Mac. It takes a G-code file that you've previously sliced in a slicer like Cura, pre-processes the code the same way M3D does it with bed level measurements, backlash compensation and feed rate translation, and finally feeds it to your printer.

MicroPrint is currently in alpha stage (or like M3D would call it; "beta!!!"), so don't expect full polish. It's meant for advanced users for now, so you need to be familiar with the command line. Like always, your printer may break if my software does something weird. It very most likely won't, but don't blame me if it does. 

Besides printing, MicroPrint can also do a few other things like retract and extrude filament manually. It extrudes until you press Return instead of the stupid repeating question in M3D's UI.

Usage examples:

    microprint print teapot.gcode
    microprint print MyPrecious0.4mmTestBorder.gcode --filament ABS
    microprint extrude --temperature 250
    microprint raise

See more by invoking `microprint --help`

Here's a good guide for how to use Cura to generate G-code: https://printm3d.com/forums/discussion/1691/guide-how-to-print-abs-out-of-the-box-using-cura

#### Notes:
* MicroPrint is not yet capable of switching from bootloader mode to firmware mode. So if you just connected the printer, launch the M3D spooler once first and let it do the switch.
* You need to quit the M3D spooler to stop it from hogging the serial port to allow MicroPrint to connect to the printer.
* No graceful aborting of prints. If you ctrl-C the program, it leaves things like the heater and fan running. You can turn off these manually with `microprint off`. I hope to fix this soon, too.
* Progress reporting is stupid and is based only on the number of processed G-code lines.
* MicroPrint requires OS X 10.10. It may very well work with older versions of OS X, but I'm not maintaining such compatibility.

Future ideas:
* Good print time estimation, with both duration and completion time.
* Interactive 0.4 mm border calibration that asks you for corner height measurements and adjusts offsets automatically.
* G-code console for executing raw G-code, with optional feed rate translation
