# Redmine Note Clone
# Copyright (C) 2026 Niltek Arge
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version. See the LICENSE file for details.

require_relative 'lib/redmine_note_clone'
require_relative 'lib/redmine_note_clone/text'
require_relative 'lib/redmine_note_clone/targets'
require_relative 'lib/redmine_note_clone/payload'
require_relative 'lib/redmine_note_clone/copier'
require_relative 'lib/redmine_note_clone/hooks'

Redmine::Plugin.register :redmine_note_clone do
  name 'Redmine Note Clone'
  author 'Niltek Arge'
  author_url 'https://github.com/oten52'
  description 'Copies an issue\'s notes, including images, onto other issues the current user can update.'
  version '0.1.0'
  url 'https://github.com/oten52/Redmine.NoteClone'
  requires_redmine version_or_higher: '4.2'

  # The git repository folder is Redmine.NoteClone. Point Redmine at this
  # directory so the plugin loads without renaming the clone.
  directory File.expand_path(__dir__)
end
