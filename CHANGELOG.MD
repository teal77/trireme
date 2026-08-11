# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Changed
- Minimum Android version is now 7.0 (API 24), pinned explicitly. It
  previously tracked whichever Flutter SDK built the app, so release builds
  shipped a 4.4 floor while local builds produced 7.0.
- Built with Flutter 3.44 and Dart 3.
- Now depends on drolevar/trireme_client v1.4.0. Its generated code is
  identical to the previous v1.3.6, so daemon communication is unchanged.

- The release APK is larger: about 50 MB, up from 22 MB. Raising the minimum
  to API 24 crosses Android's API 23 threshold, at which the build stores
  native libraries uncompressed instead of deflating them. The download is
  bigger, but the app now installs smaller and starts faster, because the
  system maps those libraries directly out of the APK instead of extracting a
  second copy.

### Fixed
- A missing case in the delete-confirmation dialog's option handling.

## [1.4.1] - 2023-12-28
### Fixed
- Theme issue in F-Droid build

## [1.4.0] - 2023-12-25
### Added
- Remember entries in torrent path dialogs and display them in an auto complete list
- Dark mode setting for following system theme
- Monochrome app icon

### Fixed
- White window background color before theme loads in
- Missing notch near bottom app bar add icon
- Dark mode not using accent colors
- Flags not displaying because countryflags.io went down (F)

## [1.4.0-beta.2] - 2023-12-10
### Added
- Dark mode setting for following system theme

### Fixed
- Fix broken torrent list when trying to display queued torrents

## [1.4.0-beta.1] - 2023-09-16
### Fixed
- Fix broken session speed indicator
- Fix wrong text color for session speed indicator
- Fix home app bar theme color in selection mode

## [1.4.0-beta] - 2023-09-13
### Added
- Remember entries in torrent path dialogs and display them in an auto complete list

### Fixed
- White window background color before theme loads in
- Missing notch near bottom app bar add icon
- Dark mode not using accent colors
- Flags not displaying because countryflags.io went down (F)

## [1.3.0] - 2020-09-25
### Added
- Add torrents by infohash
- Trackers list in torrent details > options > trackers
- Add, delete and edit trackers in trackers list

### Fixed
- Simplified torrent delete confirmation dialog
- A bug where selcting 'No Label' filter and then opening, closing filter sheet without changing anything
would clear the torrent list until filter is manually changed again.

