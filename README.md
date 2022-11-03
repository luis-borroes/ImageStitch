# ImageStitch
Image stitcher based on SIFT features, written in MATLAB.


# Sample input
![image](https://user-images.githubusercontent.com/5765119/199746211-09ffe8b2-57d1-4706-8701-277a8da25f71.png)

The stitcher works from the middle-out to spread the distortion at both edges instead of just the right side.

# Output
![image](https://github.com/luis-borroes/ImageStitch/blob/main/stitched.png?raw=true)

The result is a mosaic stitched by recognizing common features in pairs of images (SIFT features), and then finding and applying a transformation that aligns these features (and, therefore, the images).
Repeat for the full mosaic.
