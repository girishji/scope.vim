vim9script

export class AsyncCmd
    var job: job

    def Stop(how: string = '')
        if this.job->job_status() ==# 'run'
            how->empty() ? this.job->job_stop() : this.job->job_stop(how)
        endif
    enddef

    def new(cmd: any, CallbackFn: func(list<string>), poll_interval: number = 100, env: dict<any> = null_dict, ignore_err: bool = false)
        # ch_logfile('/tmp/channellog', 'w')
        # ch_log('BuildItemsList call')
        var items = []
        this.Stop('kill')
        if cmd->empty()
            return
        endif
        var start = reltime()
        this.job = job_start(cmd, {
            out_cb: (ch, str) => {
                # out_cb is invoked when channel reads a line; if you don't care
                # about intermediate output use close_cb
                items->add(str)
                if start->reltime()->reltimefloat() * 1000 > poll_interval
                    CallbackFn(items)
                    start = reltime()
                endif
            },
            close_cb: (ch) =>  CallbackFn(items),
            err_cb: (chan: channel, msg: string) => {
                if !ignore_err
                    :echohl ErrorMsg | echoerr $'error: {msg} from {cmd}' | echohl None
                endif
            },
        }->extend(env != null_dict ? {env: env} : {}))
    enddef
endclass
