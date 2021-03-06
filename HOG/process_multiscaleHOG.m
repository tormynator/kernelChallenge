function [x_p] = process_multiscaleHOG(x, p_norm)
    x = reshape(x,[size(x,1),32,32]);
    layer_d = [8,16,32];
    layer_l = 32./layer_d;
    n_bins = 12;
    x_p = zeros(size(x,1),n_bins*(layer_l*layer_l'));
    edges = (1:n_bins+1);
    for i=1:size(x,1)
        image = squeeze(x(i,:,:));
        [~,Gdir] = imgradient(image);
        Gdir(Gdir<0) = Gdir(Gdir<0)+360;
        Gdir_bin = ceil(n_bins*Gdir/360);
        for j=1:length(layer_l)
            d = layer_d(j);
            l = layer_l(j);
            for row=1:l
                for col=1:l
                    window = Gdir_bin((row-1)*d+1:row*d,(col-1)*d+1:col*d);
                    histogram = histcounts(window,edges);
                    x_p(i,n_bins*(layer_l(1:j-1)*layer_l(1:j-1)')+(row-1)*l*n_bins+(n_bins*(col-1)+1:n_bins*col)) = histogram;
                end
            end
        end
        % normalization
        if p_norm~=0
            x_p(i,:) = x_p(i,:)/norm(x_p(i,:), p_norm);
        end
    end
end