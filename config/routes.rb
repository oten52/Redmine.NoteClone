get 'issues/:id/note_copy/lookup', to: 'redmine_note_clone#lookup', as: :redmine_note_clone_lookup
get 'issues/:id/note_copy', to: 'redmine_note_clone#show', as: :redmine_note_clone
post 'issues/:id/note_copy', to: 'redmine_note_clone#create'
