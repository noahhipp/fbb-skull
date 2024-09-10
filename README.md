# fbb-skull
Quantification of off-target skull binding of [18F]florbetaben (FBB) in FBB-PET imagery using [SPM12's](https://www.fil.ion.ucl.ac.uk/spm/software/spm12/) (Wellcome Department of Cognitive Neurology) unified segmentation algorithm. [Link to paper](https://pubmed.ncbi.nlm.nih.gov/38387615/)

## A_dicom2nifti: 
Converts the DICOMs, centers the coordinate system on the geometric centroid of the respective image, and extracts patient information from the DICOM header.

## B_preprocessing:
Contains multiple modules for preprocessing PET and CT data:

**a.    do_clean_CT:** Threshold-based removal of non-informative structures (e.g., cushions, bedding, etc.).

**b.    do_coreg:** Coregistration of CT and PET scans.

**c.    do_seg:** Segments the CT and generates the corresponding flow fields for normalization into MNI space.

**d.    do_norm:** Applies the forward flow field to the CT and PET to transform them into MNI space.

**e.    do_pons_mask:** Applies a Pons mask to the transformed PET.

**f.     do_iwarp_TPM:** Applies the backward flow field to the skull tissue probability map (TPM) provided by SPM12 to transform it into patient space. Subsequently, the TPM in patient space is binarized at 0.5.

**g.    do_meanCT:** Creates an average image from all normalized CTs, thresholded at 750 HU to create another skull mask.

**h.    do_iwarp_meanCT:** Transforms the CT mean image bone mask from the MNI space to the respective patient space using the backward flow fields.

**i.      do_TPM_mask:** Applies the TPM and the binarized TPM in patient space to the native CT and PET scans.

**j.      do_meanCT_mask:** Applies the CT mean image bone mask transformed into the respective patient space to the native CT and PET scans.

## C_analysis:
Performs voxel-based calculations on the images generated in **B_preprocessing**.
