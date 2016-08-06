# G4ShareSpy

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

An iOS framework to read data from a Dexcom G4 Share receiver over Bluetooth.

## Motivation

The [Dexcom Share] app interacts with a G4 Share receiver via BLE to read continuous blood glucose data. The app displays that data in real-time, and uploads it to the Dexcom Share servers immediately.

Dexcom, in an absurd nod to obsolete FDA device classification rules, does not add the data to HealthKit until 3 hours later. For another iOS app to access the data in real-time, one option is to add unnecessary network hops and poll the Dexcom Share servers using [ShareClient]. Another option, presented here, is to spy on the Bluetooth communications between the Dexcom Share app and the G4 Share receiver.

## Usage

This project is designed to be used concurrently with the official Dexcom Share app. It does not pair with the receiver nor send commands to read data. Rather, it passively listens to the Share app's Bluetooth communications with the receiver.

To use, instantiate a `Receiver` and assign it a delegate which adopts the `ReceiverDelegate` protocol.

To see its use in a real app, see [Loop], an iOS app template for building an artificial pancreas.

## Credits

This project leverages the hard work of many others, particularly:
* [dexcom_reader] by [@compbrain]
  - decoding of the G4 receiver's packets
* [openxshareble] by [@bewest]
  - port of dexcom_reader and the G4 Share BLE protocol to Python
* [xDrip] by [@StephenBlackWasAlreadyTaken]
  - port of dexcom_reader and the G4 Share BLE protocol to Android
* [xDripG5] by [@loudnate]
  - decoding of the Dexcom G5 BLE communications

## Disclaimer

This project is neither created nor endorsed by Dexcom, Inc. This software is not intended for use in therapy.

[@bewest]: https://github.com/bewest
[@compbrain]: https://github.com/compbrain
[@loudnate]: https://github.com/loudnate
[@StephenBlackWasAlreadyTaken]: https://github.com/StephenBlackWasAlreadyTaken
[Dexcom Share]: https://www.dexcom.com/dexcom-g4-platinum-share
[dexcom_reader]: https://github.com/compbrain/dexcom_reader
[Loop]: https://github.com/loudnate/Loop
[openxshareble]: https://github.com/bewest/openxshareble
[ShareClient]: https://github.com/mddub/dexcom-share-client-swift
[xDrip]: https://github.com/StephenBlackWasAlreadyTaken/xDrip
[xDripG5]: https://github.com/loudnate/xDripG5
