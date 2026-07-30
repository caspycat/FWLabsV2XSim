function [selectedSuite, excludedPublicationCampaignCount] = ...
        selectRegressionCampaigns(suite, includePublicationCampaigns)
%SELECTREGRESSIONCAMPAIGNS Apply the correctness-gate campaign policy.
%   Routine regressions and shortened conclusion-level campaigns remain in
%   the selected suite. Registered full-duration campaigns must carry the
%   PublicationCampaign tag and require an explicit caller opt-in.

arguments (Input)
    suite matlab.unittest.TestSuite
    includePublicationCampaigns (1, 1) logical
end

arguments (Output)
    selectedSuite matlab.unittest.TestSuite
    excludedPublicationCampaignCount (1, 1) double ...
        {mustBeInteger, mustBeNonnegative}
end

if includePublicationCampaigns
    selectedSuite = suite;
    excludedPublicationCampaignCount = 0;
    return
end

publicationSelector = ...
    matlab.unittest.selectors.HasTag("PublicationCampaign");
selectedSuite = suite.selectIf(~publicationSelector);
excludedPublicationCampaignCount = ...
    numel(suite) - numel(selectedSuite);
end
