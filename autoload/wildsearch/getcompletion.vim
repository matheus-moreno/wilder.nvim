func wildsearch#getcompletion#parse(cmdline) abort
  if exists('s:cache_cmdline') && a:cmdline ==# s:cache_cmdline
    return s:cache
  else
    let l:ctx = {'cmdline': a:cmdline, 'pos': 0, 'cmd': ''}
    call wildsearch#getcompletion#main#do(l:ctx)

    let s:cache = l:ctx
    let s:cache_cmdline = a:cmdline
  endif

  return copy(l:ctx)
endfunc

function! wildsearch#getcompletion#has_file_args(cmd)
  return wildsearch#getcompletion#main#has_file_args(a:cmd)
endfunction

function! wildsearch#getcompletion#is_user_command(cmd)
  return !empty(a:cmd) && a:cmd[0] >=# 'A' && a:cmd[0] <=# 'Z'
endfunction

function! wildsearch#getcompletion#get_user_completion(cmdline)
  let l:ctx = wildsearch#getcompletion#parse(a:cmdline)

  let l:user_commands = nvim_get_commands({})

  if !has_key(l:user_commands, l:ctx.cmd)
    return v:false
  endif

  let l:user_command = l:user_commands[l:ctx.cmd]

  if has_key(l:user_command, 'complete') &&
        \ l:user_command.complete !=# 'custom' && l:user_command.complete !=# 'customlist'
    let l:completions = getcompletion(l:ctx.cmdline[l:ctx.pos :], l:user_command.complete)

    if l:user_command.complete ==# 'file' ||
          \ l:user_command.complete ==# 'file_in_path' ||
          \ l:user_command.complete ==# 'dir'
      return map(l:completions, {_, x -> escape(x, ' ')})
    endif

    return l:completions
  endif

  if !has_key(l:user_command, 'complete_arg') || l:user_command.complete_arg is v:null
    return v:false
  endif

  let l:Completion_func = function(l:user_command.complete_arg)

  " pos + 1 for the command prompt
  return l:Completion_func(l:ctx.cmdline[l:ctx.pos :], l:ctx.cmdline, l:ctx.pos + 1)
endfunction

func wildsearch#getcompletion#replace(ctx, cmdline, x) abort
  let l:result = wildsearch#getcompletion#parse(a:cmdline)

  if l:result.pos == 0
    return a:x
  endif

  if match(l:result.cmd, 'menu$') != -1
    return l:result.cmdline[: l:result.pos - 1] . a:x
  endif

  return l:result.cmdline[: l:result.pos - 1] . a:x
endfunction

function! wildsearch#getcompletion#pipeline(opts) abort
  let l:skip = get(a:opts, 'skip', {
        \ 'substitute': v:true,
        \ 'smagic': v:true,
        \ 'snomagic': v:true,
        \ 'global': v:true,
        \ 'vglobal': v:true,
        \ '&': v:true,
        \ })

  return [
      \ wildsearch#check({-> getcmdtype() ==# ':'}),
      \ {_, x -> wildsearch#getcompletion#parse(x)},
      \ {_, res -> has_key(l:skip, res.cmd) ? l:skip[res.cmd] : res},
      \ {_, res -> wildsearch#getcompletion#is_user_command(res.cmd) ?
      \   wildsearch#getcompletion#get_user_completion(res.cmdline) :
      \   wildsearch#getcompletion#has_file_args(res.cmd) ?
      \   map(getcompletion(res.cmdline, 'cmdline'), {_, x -> escape(x, ' ')}) :
      \   getcompletion(res.cmdline, 'cmdline')
      \ },
      \ {_, xs -> map(xs, {_, x -> {'result': x, 'replace': 'wildsearch#getcompletion#replace'}})},
      \ ]
endfunction