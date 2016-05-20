function [y,ii,idx]=block_sort(y,ii,blk)
idx=1:length(ii);
for i=1:length(blk)
    ind=blk{i}(1):blk{i}(2);
    [yt,ix]=sort(y(ind),'ascend');
    y(ind)=yt;
    it=ii(ind);
    ii(ind)=it(ix);
    idx(ind)=ind(ix);
end