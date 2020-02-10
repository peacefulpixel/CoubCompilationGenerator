# CoubCompilationGenerator
A Bash script that generates video using coub api and ffmpeg

## Installation
TODO: Descript requirements and an installation process here

## Usage
TODO: Descript all phases of video coreating process here

## Known issues and solutions
### FFMPEG are cyclically fails and prints errors
Some video/audio media may not to be applicable to some operations for now.
So if you just press `<C-c>` shortcut, it will stop process and then you can
find the video that causes problems by name in ffmpeg logs and delete it.
Then you can restart an operation.

In all cases i got this problem, it solved it
### Final video are defected
Make sure your outro/intro video have correct codec/resolution/framerate/etc..<br>
You can compare it by `ffmpeg -i /path/to/your/media`.
### Flags like `-p`/`-r`/etc.. doesn't applies
An order of the flags metters. Then if you try something like:
```shell
ccg -d -p 10
```
It will download videos at first, then sets pages amount to 10<br>
If reordering doesn't helps you, chang thee parameters in an entire script
