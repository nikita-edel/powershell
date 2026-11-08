bleopt default_keymap=vi

ble-bind -m vi_imap -Cursor 5
ble-bind -m vi_nmap -Cursor 2
ble-bind -m vi_omap -Cursor 4
ble-bind -m vi_xmap -Cursor 2
ble-bind -m vi_smap -Cursor 2

ble-bind -m vi_imap -f Y -
ble-bind -m vi_nmap -f Y -
ble-bind -m vi_xmap -f Y -
ble-bind -m vi_smap -f Y -

bleopt complete_auto_view=list
bleopt complete_auto_view_maxlines=5
bleopt complete_auto_view_completion=word
bleopt complete_auto_view_selected=color
ble-face 'list_view_selected_color=fg=#ffff00,bold'

bleopt complete_auto_view_ambiguous=1
bleopt complete_auto_delay=1

ble-bind -m vi_imap -f 'M-j' history-search-backward
ble-bind -m vi_imap -f 'M-k' history-search-forward
ble-bind -m vi_xmap -s 'Y' '" + y'

bleopt complete_auto_history_cwd=1
bleopt complete_auto_history_validate=command:path
bleopt complete_auto_history_multiline=0

bleopt 'prompt_capslock_indicator=  \e[31m^^\e[m'
bleopt keymap_vi_mode_show=
bleopt 'prompt_bottom_left=\q{keymap:vi/mode-indicator}'
bleopt 'prompt_bottom_center=\w'
bleopt 'prompt_bottom_right= \A'

bleopt capslock_reserve=1
bleopt 'prompt_input_after=\q{capslock}'
bleopt prompt_input_after_position=before

bleopt complete_auto_history_fuzzy=1

if (Get-Command fzf -ErrorAction Ignore) {
	$env:FZF_DEFAULT_OPTS = '--bind=alt-j:down,alt-k:up,ctrl-d:half-page-down,ctrl-u:half-page-up'

	ble-import integration/fzf
	ble-bind -Reset 'C-t', 'C-r', 'M-c'

	ble-bind -Always -f M-u fzf-history-widget
	ble-bind -Always -f M-i fzf-file-widget
	ble-bind -Always -f M-o fzf-command-widget
}

bleopt complete_auto_view_tips=0
bleopt complete_auto_view_min_width=50
bleopt complete_auto_view_min_height=10
bleopt complete_auto_hide_command_paths=1
