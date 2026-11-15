# F-Droid metadata

The store listing lives in `metadata/android/en-US/`, using F-Droid's
[Fastlane structure](https://f-droid.org/en/docs/All_About_Descriptions_Graphics_and_Screenshots/).
The Fastlane tools are not required.

- `title.txt`, `short_description.txt`, and `full_description.txt` contain the listing text.
- `images/icon.png` is copied from the Android xxxhdpi launcher icon.
- `images/phoneScreenshots/` contains the four screenshots from
  [the existing album](https://imgur.com/a/x7QOi6r), in album order. These show the 2018 interface.
- `changelogs/<versionCode>.txt` contains release notes for the Android version code
  in `android/app/build.gradle`, with a maximum of 500 characters per file.

Add metadata and release notes before tagging a release: F-Droid reads them from
its latest known release, rather than the development branch. The short description
must be at most 80 characters and the full description at most 4000 characters.

The existing `Name` and `Description` fields in
[fdroiddata](https://gitlab.com/fdroid/fdroiddata/-/blob/master/metadata/org.deluge.trireme.yml)
override the corresponding upstream text. Once this metadata is available in a
release used by F-Droid, request removal of those fields so this directory controls
the listing. Build recipes, license, categories, and update settings remain in fdroiddata.
