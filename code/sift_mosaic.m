function mosaic = sift_mosaic()

    %load all images from directory
    imgDir = dir('../data');
    filenames = strcat('../data/', {imgDir.name});
    
    %remove img/. and img/..
    filenames = filenames(1, 3:end);
    
    %convert to integer so we can do integer division
    imgNo = uint32(numel(filenames));
    images = {};
    
    for i = 1:imgNo
        images{i} = imread(fullfile(filenames{i}));
    end

    
    %initialize the keypoint and descriptor arrays
    f = {};
    d = {};

    %for every image, greyscale it and use vl_sift to find its keypoints
    %and descriptors
    for i = 1:imgNo
        single = im2single(images{i});
        gray = rgb2gray(single);
        [fi, di] = vl_sift(gray);
        f{i} = fi;
        d{i} = di;
    end
    
    
    %find the mindpoint of our image array (rounding up: 2.5 -> 3)
    %this is our starting image, we then add images onto it
    %alternating each side every time
    index = idivide(imgNo, 2, 'ceil');
    
    for i = 0:(imgNo - 1)
        
        %by alternating adding or removing i from index, we get a sequence
        %of integers "spreading" out from our mid point
        % index(1) = 3
        %        i = 0 1 2 3 4
        % index(n) = 3 4 2 5 1
        if mod(i, 2) == 0
            index = index - i;
            
        else
            index = index + i;
        end
        
        
        %if it's the first image, initialize the mosaic, keypoint and
        %descriptor variables
        if i == 0
            mosaic = images{index};
            fi = f{index};
            di = d{index};
            
        %otherwise, start stitching onto mosaic
        else
            [points1, points2, numMatches] = match(fi, di, f{index}, d{index});
            H = ransac(points1, points2, numMatches);
            mosaic = getMosaic(mosaic, images{index}, H);
            
            %only calculate sift descriptors until its the last image
            if i < (imgNo - 1)
                single = im2single(mosaic);
                gray = rgb2gray(single);
                [fi, di] = vl_sift(gray);
            end
        end
        
    end
    
    imagesc(mosaic);
    axis image off;
    title('Mosaic');
    
    imwrite(mosaic, '..\stitched.png');
end


%use vl_ubcmatch to find the matches between the descriptors of two
%images, and then return the groups of points corresponding to these
%matches (equal indices = coordinates of the point in either image)
function [points1, points2, numMatches] = match(f1, d1, f2, d2)
    [matches, scores] = vl_ubcmatch(d1, d2);

    numMatches = size(matches, 2);

    points1 = f1(1:2, matches(1, :));
    points2 = f2(1:2, matches(2, :));

    points1(3,:) = 1;
    points2(3,:) = 1;
end


%use ransac to calculate the transformation
function H = ransac(X1, X2, numMatches)
    for t = 1:100
      % estimate homography
      subset = vl_colsubset(1:numMatches, 4) ;
      A = [] ;
      for i = subset
        A = cat(1, A, kron(X1(:,i)', vl_hat(X2(:,i)))) ;
      end
      [U,S,V] = svd(A) ;
      H{t} = reshape(V(:,9),3,3) ;

      % score homography
      X2_ = H{t} * X1 ;
      du = X2_(1,:)./X2_(3,:) - X2(1,:)./X2(3,:) ;
      dv = X2_(2,:)./X2_(3,:) - X2(2,:)./X2(3,:) ;
      ok{t} = (du.*du + dv.*dv) < 6*6 ;
      score(t) = sum(ok{t}) ;
    end

    [score, best] = max(score) ;
    H = H{best} ;
    ok = ok{best} ;
end


%combine two pictures into a mosaic, using the obtained transformation
function mosaic = getMosaic(im1, im2, H)
    box2 = [1  size(im2,2) size(im2,2)  1 ;
            1  1           size(im2,1)  size(im2,1) ;
            1  1           1            1 ] ;
    box2_ = inv(H) * box2 ;
    box2_(1,:) = box2_(1,:) ./ box2_(3,:) ;
    box2_(2,:) = box2_(2,:) ./ box2_(3,:) ;
    ur = min([1 box2_(1,:)]):max([size(im1,2) box2_(1,:)]) ;
    vr = min([1 box2_(2,:)]):max([size(im1,1) box2_(2,:)]) ;

    [u,v] = meshgrid(ur,vr) ;
    im1_ = vl_imwbackward(im2double(im1),u,v) ;

    z_ = H(3,1) * u + H(3,2) * v + H(3,3) ;
    u_ = (H(1,1) * u + H(1,2) * v + H(1,3)) ./ z_ ;
    v_ = (H(2,1) * u + H(2,2) * v + H(2,3)) ./ z_ ;
    im2_ = vl_imwbackward(im2double(im2),u_,v_) ;

    mass = ~isnan(im1_) + ~isnan(im2_) ;
    im1_(isnan(im1_)) = 0 ;
    im2_(isnan(im2_)) = 0 ;
    mosaic = (im1_ + im2_) ./ mass ;
end
