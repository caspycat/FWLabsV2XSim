function standardDeviationMeters = ...
        cartesianGaussianAxisStandardDeviation(meanMagnitudeMeters)
%CARTESIANGAUSSIANAXISSTANDARDDEVIATION Match a Rayleigh mean magnitude.
%   For independent zero-mean Cartesian Gaussian X and Y errors with
%   common standard deviation sigma, the displacement magnitude is
%   Rayleigh distributed with mean sigma*sqrt(pi/2).

arguments (Input)
    meanMagnitudeMeters double ...
        {mustBeReal, mustBeFinite, mustBeNonnegative}
end

standardDeviationMeters = ...
    meanMagnitudeMeters .* sqrt(2 ./ pi);
end
