classdef HFSSSessionMonitor < handle
    % Poll only when the application is idle: COM calls are synchronous.
    properties
        Timer = []
        Session
        Callback = []
        Busy = false
    end
    methods

        function o = HFSSSessionMonitor(session, callback)
            o.Session = session;
            if nargin > 1
                o.Callback = callback;
            end
        end

        function start(o)
            if ~isempty(o.Timer)
                return
            end
            o.Timer = timer('ExecutionMode', 'fixedSpacing', 'Period', 5, 'BusyMode', 'drop', ...
                            'TimerFcn', @(~, ~)o.tick());
            start(o.Timer);
        end

        function tick(o)
            if o.Busy
                return
            end
            alive = o.Session.ping();
            if ~isempty(o.Callback)
                o.Callback(alive);
            end
        end

        function delete(o)
            if ~isempty(o.Timer)
                try
                    stop(o.Timer);
                    delete(o.Timer);
                catch
                end
            end
        end

    end
end
