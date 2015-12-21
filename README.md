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
* You need to quit the M3D spooler to stop it from hogging the serial port to allow MicroPrint to connect to the printer.
* No graceful aborting of prints. If you ctrl-C the program, it leaves things like the heater and fan running. I hope to fix this soon, too.
* Progress reporting is stupid and is based only on the number of processed G-code lines.
* MicroPrint requires OS X 10.10. It may very well work with older versions of OS X, but I'm not maintaining such compatibility.

Future ideas:
* Good print time estimation, with both duration and completion time.
* Interactive 0.4 mm border calibration that asks you for corner height measurements and adjusts offsets automatically.
* G-code console for executing raw G-code, with optional feed rate translation

##### Simplify3d Setup

To use Simplify3d effectively you will need to change the Process definition for the Micro3d printer. We suggest that you
make the following changes then save the definition under a different name.

1. Edit the Process, usually "Process1"
1. You should have `M3D Micro` selected as the Profile
1. Select the `Scripts` tab
1. Under "Additional terminal commands" **DELETE** the following lines:
    * `{STRIP ";"}`
    * `{PREPEND ";other temp:210\n;ideal temp:210\n"}`
1. Click "Save as New" and enter a new name for this profile. `M3D Micro - Microprint` might be a good name.

If this is successful then the resulting GCode will have the Simplify3d Profile and Layer indicators in it.
Microprint should detect these and display the settings during print setup and the layer progress as the print proceeds.
