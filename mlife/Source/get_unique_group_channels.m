function [nChannels, channels] = get_unique_group_channels(nTotalGroupChannels, nGroups, Groups)
   allChannels = zeros(1, nTotalGroupChannels);
   channelIndex = 1;
% Loop over channels from DEL groups
   for iGroup=1:nGroups
      nGroupChannels = length(Groups(iGroup).channelIndices);
      allChannels(channelIndex:channelIndex+nGroupChannels-1) = Groups(iGroup).channelIndices;
      channelIndex=channelIndex+nGroupChannels;
   end
   channels = unique(sort(allChannels));
   nChannels = length(channels);
end