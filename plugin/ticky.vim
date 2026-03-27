if exists('g:loaded_ticky') | finish | endif
let g:loaded_ticky = 1

" :Ticky  – open the ticky TUI in a floating window
command! -nargs=0 Ticky lua require('ticky').open()

" :TickyToggle  – toggle the ticky floating window
command! -nargs=0 TickyToggle lua require('ticky').toggle()
