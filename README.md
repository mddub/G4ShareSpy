# G4ShareSpy

An iOS framework to read data from a Dexcom G4 Share receiver over Bluetooth.

This project leverages the hard work of many others, particularly:
* [dexcom_reader] by @compbrain
* [openxshareble] by @bewest
* [xDrip] by @StephenBlackWasAlreadyTaken
* [xDripG5] by @loudnate

## Usage

This project is designed to be used concurrently with the official Dexcom Share app. It does not pair with the receiver nor send commands to read data. Rather, it passively listens to the Share app's Bluetooth communications with the receiver.

## Disclaimer

This project is neither created nor endorsed by Dexcom, Inc. This software is not intended for use in therapy.

[dexcom_reader]: https://github.com/compbrain/dexcom_reader
[openxshareble]: https://github.com/bewest/openxshareble
[xDrip]: https://github.com/StephenBlackWasAlreadyTaken/xDrip
[xDripG5]: https://github.com/loudnate/xDripG5
