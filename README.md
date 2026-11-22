# Redmine Note Clone

Copies the notes under an issue, together with their images, onto other issues.

[Türkçe](README.tr.md)

## What's new

* 0.1.0: First release. See [CHANGELOG](CHANGELOG.md).

## Features

* On an issue that has notes, two actions appear in the issue menu:
  * **Copy notes** opens a side panel.
  * **Copy directly** sends the notes without opening the panel.
* The side panel lists every visible note. The text can be edited before it is sent, and each image can be included or left out.
* Related issues start selected. Parent and subtasks are listed and start unselected.
* Any other issue can be added by number, limited to issues the current user is allowed to view and update.
* Images referenced by a note, and files added with that note, are copied onto the target issue. The note text is rewritten so the image still renders there.
* **Copy directly** uses the original text and images and only the related issues the user can update. A confirmation lists those issues.
* The new note is written by the current user. A source line can keep the original author and time.
* Watchers are not notified unless **Notify watchers** is checked in the panel.
* Translated into English and Turkish.

## Required Redmine version

* 4.2.x ~ 6.x

No database migrations and no gems.

## Install

1. From the Redmine `plugins` directory:

```bash
git clone https://github.com/oten52/Redmine.NoteClone.git redmine_note_clone
```

2. Copy the assets and restart Redmine:

```bash
bundle exec rake redmine:plugins:assets RAILS_ENV=production
```

The links show on an issue that already has notes, in the action menu next to Edit.

## Uninstall

1. Remove the `plugins/redmine_note_clone` folder.
2. Restart Redmine.

## Author

Niltek Arge — https://github.com/oten52

## License

GNU General Public License v3.0 or later. See [LICENSE](LICENSE).

If you modify and distribute this plugin, keep the copyright notices, state your changes and
distribute your version under the same license.
