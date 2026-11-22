# frozen_string_literal: true

# Redmine Note Clone
# Copyright (C) 2026 Niltek Arge
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version. See the LICENSE file for details.

module RedmineNoteClone
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_issues_show_details_bottom, partial: 'redmine_note_clone/launcher'
  end
end
