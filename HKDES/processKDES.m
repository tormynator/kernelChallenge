function [x_patches, x_patch_statistics] = processKDES(x,gamma_o,gamma_p,gamma_c,gamma_b,eps_g,eps_s,window_size,stride,T_grad, T_col, T_shape)
    x = reshape(x,[size(x,1),32,32]);
    l = floor((32-window_size)/stride)+1;
    
    x_patches = zeros(size(x,1),l^2*(T_grad+T_col+T_shape));
    
    disp('Creating basis points');
    % Creation of the basis points of k_o
    grid_o = linspace(0,2*pi,25)';
    grid_o = grid_o(1:end-1);
    X_o = [cos(grid_o) sin(grid_o)];
    % Creation of the basis points of k_c
    X_c = linspace(-1/3,1/3,5)';
    % Creation of the basis points of k_p
    grid_p = linspace(0,1,5);
    [meshX,meshY] = meshgrid(grid_p);
    X_p = [meshX(:) meshY(:)];
    % Creation of the basis points of k_b
    grid_b = dec2bin((0:2^8-1),8);
    X_b = zeros(2^8,8);
    for s=1:8
        X_b(:,s) = str2num(grid_b(:,s)); %#ok<ST2NM>
    end
    
    disp('Building Gram matrices of basis vectors');
    % Gram matrix of k_o
    K_o = rbf(X_o,X_o,gamma_o);
    % Gram matrix of k_c
    K_c = rbf(X_c,X_c,gamma_c);
    % Gram matrix of k_p
    K_p = rbf(X_p,X_p,gamma_p);
    % Gram matrix of k_b
    K_b = rbf(X_b,X_b,gamma_b);
    
    disp('Performing KPCA on basis vectors');
    % KPCA on the basis vectors phi_o x phi_p
    [alpha_op,~] = KPCA(kron(K_p,K_o),T_grad);
    % KPCA on the basis vectors phi_c x phi_p
    [alpha_cp,~] = KPCA(kron(K_p,K_c),T_col);
    % KPCA on the basis vectors phi_b x phi_p
    [alpha_bp,~] = KPCA(kron(K_p,K_b),T_shape);
    
    % Position vectors z
    grid_z = linspace(0,1,window_size);
    [meshX,meshY] = meshgrid(grid_z);
    Z = [meshY(:) meshX(:)];
    
    % Loop over the images
    disp('Computing kernel descriptors');
    parfor i=1:size(x,1)
        fprintf('Computing kernel descriptors for image %i\n',i);

        % Extract the image
        image = squeeze(x(i,:,:));
        
        patch_features = zeros(l^2,T_grad+T_col+T_shape);
        patch_statistics = zeros(l^2,2);
        
        % Compute the directions of the gradient
        [Gmag,Gdir] = imgradient(image);
        % Loop over the patches in the image
        for row=1:l
            for col=1:l
                window_r = (row-1)*stride+(1:window_size);
                window_c = (col-1)*stride+(1:window_size);
                % Computation of m_tilde (formula (2))
                m = reshape(Gmag(window_r,window_c),window_size^2,1);
                m_mean = mean(m);
                m = m/sqrt(sum(m.^2)+eps_g);
                % Computation of theta_tilde (formula (6))
                theta = reshape(Gdir(window_r,window_c),window_size^2,1);
                theta = [cosd(theta) sind(theta)];
                % Computation of c (formula (7))
                c = reshape(image(window_r,window_c),window_size^2,1);
                % Computation of s_tilde and b (formula(8))
                s = zeros(window_size^2,1);
                b = zeros(window_size^2,8);
                for z_i = 1:window_size
                    for z_j = 1:window_size
                        std_window_r = (row-1)*stride+(z_i-1:z_i+1);
                        std_window_r = std_window_r(std_window_r>0 & std_window_r<=32);
                        std_window_c = (col-1)*stride+(z_j-1:z_j+1);
                        std_window_c = std_window_c(std_window_c>0 & std_window_c<=32);
                        s_pixels = image(std_window_r,std_window_c);
                        s_pixels(find(s_pixels==image((row-1)*stride+z_i,(col-1)*stride+z_j),1)) = [];
                        s((z_i-1)*window_size+z_j) = std(s_pixels);
                        b_pixels = zeros(3,3);
                        b_pixels(std_window_r-(row-1)*stride-z_i+2,std_window_c-(col-1)*stride-z_j+2) = image(std_window_r,std_window_c)>image((row-1)*stride+z_i,(col-1)*stride+z_j);
                        b_pixels = reshape(b_pixels,9,1);
                        b_pixels(5) = [];
                        b((z_i-1)*window_size+z_j,:) = b_pixels';
                    end
                end
                s_mean = mean(s);
                s = s/sqrt(sum(s.^2)+eps_s);
                
                % Gram matrix of k_o
                K_o = rbf(theta,X_o,gamma_o);
                % Gram matrix of k_c
                K_c = rbf(c,X_c,gamma_c);
                % Gram matrix of k_p
                K_p = rbf(Z,X_p,gamma_p);
                % Gram matrix of k_b
                K_b = rbf(b,X_b,gamma_b);
                
                % Compute F_grad(P) (formula (12))
                F_grad = kernel_descriptors(m, K_o, K_p, alpha_op);
                % Compute F_col(P) (derived from formula (7))
                F_col = kernel_descriptors(ones(window_size^2,1), K_c, K_p, alpha_cp);
                % Compute F_shape(P) (derived from formula (8))
                F_shape = kernel_descriptors(s, K_b, K_p, alpha_bp);
                
                % Put together patch features
                patch_features((row-1)*l+col,:) = [F_grad F_col F_shape];
                patch_statistics((row-1)*l+col,:) = [m_mean s_mean];
            end
        end
        x_patches(i,:) = reshape(patch_features',[1,l^2*(T_grad+T_col+T_shape)]);
        x_patch_statistics(i,:) = reshape(patch_statistics',[1,l^2*2]);
    end
end