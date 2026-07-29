function warnIfSlowV7Example(elapsedSeconds)
%WARNIFSLOWV7EXAMPLE Emit an advisory warning for a slow example.

arguments (Input)
    elapsedSeconds (1,1) double ...
        {mustBeReal,mustBeFinite,mustBeNonnegative}
end

if elapsedSeconds > 30
    warning( ...
        "v2xsimexample:SlowExample", ...
        "This example took %.1f seconds on this computer.", ...
        elapsedSeconds);
end
end
