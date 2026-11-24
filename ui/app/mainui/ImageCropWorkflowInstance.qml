import shared.popups

ImageCropWorkflow {
    id: root

    title: qsTranslate("Popups", "Profile Picture")
    acceptButtonText: qsTranslate("Popups", "Make this my Profile Pic")
    onImageCropped: (image, cropRect) => {
        if (!callback) {
            console.error("ImageCropWorkflow: no callback provided")
            return
        }
        callback(image,
                 cropRect.x.toFixed(),
                 cropRect.y.toFixed(),
                 (cropRect.x + cropRect.width).toFixed(),
                 (cropRect.y + cropRect.height).toFixed())
    }
    onDone: destroy()
}
