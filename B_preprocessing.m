function B_preprocessingV2
% Contains all preprocessing steps (except centering the origin, which is
% handled by dicom2nifti) for fbb-skull investigation

% Housekeeping constants)
SCRIPT_LOCATION     = fileparts(mfilename("fullpath"));
BASE_DIR            = fullfile(SCRIPT_LOCATION, "..");
DATA_DIR            = fullfile(BASE_DIR, 'data');
SPM_DIR             = fileparts(which('spm'));

PET_DIR_TEMPL       = 'pet'; % single quotes --> char --> indexable
CT_DIR_TEMPL        = 'ct';

% CT names
CT_TEMPL            = 'ct01.nii';
WCT_TEMPL           = 'wct01.nii';
MEAN_CT_TEMPL       = 'mean_ct.nii';
MEAN_CT_SKULL_TEMPL = 'mean_ct_skull.nii';
iwMEAN_CT_SKULL_TEMPL = 'iwmean_ct_skull.nii';
CT_SKULLmeanCT750_TEMPLATE = 'ct01_skullmeanCT750';

CT_SKULLTPM_TEMPL   = 'ct01_skullTPM.nii';
CT_SKULLTPMb05_TEMPL = 'ct01_skullTPMb05.nii';

% PET names
PET_TEMPL           = 'pet01.nii';
PET_SKULL_TEMPL     = 'pet01_skull.nii';
WPET_TEMPL          = 'wpet01.nii';
WPET_PONS_TEMPL     = 'wpet01_pons.nii';
CENTILOID_PET_TEMPL = 'centiloidpet01.nii';
CENTILOID_PET_SKULL_TEMPL = 'centiloidpet01_skull.nii';
PET_SKULLmeanCT750_TEMPLATE = 'pet01_skullmeanCT750';

PET_SKULLTPM_TEMPL   = 'pet01_skullTPM.nii';
PET_SKULLTPMb05_TEMPL = 'pet01_skullTPMb05.nii';

% Masks
MNI_PONS_MASK       = fullfile(DATA_DIR, "voi_Pons_2mm.nii");

% Mean CT
MEAN_CT             = fullfile(DATA_DIR, MEAN_CT_TEMPL);
MEAN_CT_SKULL       = fullfile(DATA_DIR, MEAN_CT_SKULL_TEMPL); 
iwMEAN_CT_SKULL     = fullfile(DATA_DIR, iwMEAN_CT_SKULL_TEMPL);

% Flowfields
ns2MNI_TEMPLATE = strcat('y_', CT_TEMPL);
MNI2ns_TEMPLATE = strcat('iy_', CT_TEMPL);

% TPMs
spm_TPM_skull   = fullfile(SPM_DIR, 'tpm', 'TPM.nii,4');
iw_TPM_TEMPLATE = 'iwTPM.nii';
iw_TPMb05_TEMPLATE = 'iwTPMb05.nii';
iw_spm_TPM_skull = fullfile(SPM_DIR, 'tpm', iw_TPM_TEMPLATE);

% Collect patient file
PATIENT_FILE = fullfile(BASE_DIR, "patients.mat");
load(PATIENT_FILE, "patients");

SUBS = 1:44;

% Settings
debug                           = 0;

% First batch
do_clean_CT                     = 1;
do_coreg                        = 1; % CT to PET
do_seg                          = 1; % CT
do_norm                         = 1; % CT and PET to MNI
do_pons_mask                    = 1; % apply MNI pons to warped PET
do_iwarp_TPM                    = 1; % warp tpm to native space and generate binarized TPM

% Mean CT generation (CAVE: This requires the first batch to be done AND is
% required by the second batch modules. has to run before the second batch
% modules)
do_meanCT                       = 0; % generate mean CT

% Second batch (CAVE: This requires the first batch to be done AND the
% meanCT generation to be done as well)
do_TPM_mask                     = 0; % apply warped TPM and warped binarized TPM to PET and CT

do_iwarp_meanCT                 = 0; % warp the meanCT to respective patient space. CAVE: 
do_meanCT_mask                  = 0; % apply the warped meanCT to respective PET and CT




% Loop over subjects
for i = 1:numel(SUBS)

    % Reset matlabbatch
    matlabbatch = [];
    mbi         = 0;

    % Define subject specific paths
    sub                     = SUBS(i);
    sub_dir                 = fullfile(DATA_DIR, patients.folder(sub));
    fprintf("Preparing first batch for %s\n... ", sub_dir);
    ct_dir                  = fullfile(sub_dir, CT_DIR_TEMPL);    
    pet_dir                 = fullfile(sub_dir, PET_DIR_TEMPL);
    
    ct                      = fullfile(ct_dir, CT_TEMPL);
    ct_skullTPM             = fullfile(ct_dir, CT_SKULLTPM_TEMPL);
    ct_skullTPMb05          = fullfile(ct_dir, CT_SKULLTPMb05_TEMPL);
    ct_skullmeanCT750       = fullfile(ct_dir, CT_SKULLmeanCT750_TEMPLATE);
   

    mean_ct_skull_mask           = fullfile(ct_dir, iwMEAN_CT_SKULL_TEMPL);

    pet                     = fullfile(pet_dir, PET_TEMPL);
    pet_skull               = fullfile(pet_dir, PET_SKULL_TEMPL);

    pet_skullTPM             = fullfile(pet_dir, PET_SKULLTPM_TEMPL);
    pet_skullTPMb05          = fullfile(pet_dir, PET_SKULLTPMb05_TEMPL);
    pet_skullmeanCT750       = fullfile(pet_dir, PET_SKULLmeanCT750_TEMPLATE);

    wpet                    = fullfile(pet_dir, WPET_TEMPL);
    wpet_pons               = fullfile(pet_dir, WPET_PONS_TEMPL);
    centiloid_pet           = fullfile(pet_dir, CENTILOID_PET_TEMPL);
    centiloid_pet_skull     = fullfile(pet_dir, CENTILOID_PET_SKULL_TEMPL);

    iw_tpm                  = fullfile(sub_dir, iw_TPM_TEMPLATE);
    iw_tpmb05               = fullfile(sub_dir, iw_TPMb05_TEMPLATE);

    ns2MNI_flowfield       = fullfile(ct_dir, ns2MNI_TEMPLATE);
    MNI2ns_flowfield       = fullfile(ct_dir, MNI2ns_TEMPLATE);

    bb = spm_get_bbox(char(pet)); % this defines the bbox of our warp targets

    % Clean low dose CT (get rid of outside low density structures as suggested in Presotto
    % et al. 2018) and apply PET BBox to CT
    if do_clean_CT
        hdr = spm_vol(char(ct));
        vols = spm_read_vols(hdr);
        % ==========================================
        vols(vols < -300) = -1024;
        % ==========================================
        spm_write_vol(hdr, vols);

       resize_img(char(ct), [nan nan nan], bb);
    end

    % Coregistration (coregister CT to PET)
    if do_coreg
        mbi = mbi + 1;
        matlabbatch{mbi}.spm.spatial.coreg.estimate.ref = cellstr(pet);
        matlabbatch{mbi}.spm.spatial.coreg.estimate.source = cellstr(ct);
        matlabbatch{mbi}.spm.spatial.coreg.estimate.other = {''};
        matlabbatch{mbi}.spm.spatial.coreg.estimate.eoptions.cost_fun = 'nmi';
        matlabbatch{mbi}.spm.spatial.coreg.estimate.eoptions.sep = [4 2];
        matlabbatch{mbi}.spm.spatial.coreg.estimate.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
        matlabbatch{mbi}.spm.spatial.coreg.estimate.eoptions.fwhm = [7 7];
    end

    % Segment CT and obtain forward and backwards transformations
    if do_seg
        mbi = mbi + 1;
        matlabbatch{mbi}.spm.spatial.preproc.channel.vols = cellstr(ct);
        matlabbatch{mbi}.spm.spatial.preproc.channel.biasreg = 0;
        matlabbatch{mbi}.spm.spatial.preproc.channel.biasfwhm = 60;
        matlabbatch{mbi}.spm.spatial.preproc.channel.write = [0 0];
        matlabbatch{mbi}.spm.spatial.preproc.tissue(1).tpm = {'/home/noah/spm12/tpm/TPM.nii,1'};
        matlabbatch{mbi}.spm.spatial.preproc.tissue(1).ngaus = 1;
        matlabbatch{mbi}.spm.spatial.preproc.tissue(1).native = [1 0];
        matlabbatch{mbi}.spm.spatial.preproc.tissue(1).warped = [0 0];
        matlabbatch{mbi}.spm.spatial.preproc.tissue(2).tpm = {'/home/noah/spm12/tpm/TPM.nii,2'};
        matlabbatch{mbi}.spm.spatial.preproc.tissue(2).ngaus = 1;
        matlabbatch{mbi}.spm.spatial.preproc.tissue(2).native = [1 0];
        matlabbatch{mbi}.spm.spatial.preproc.tissue(2).warped = [0 0];
        matlabbatch{mbi}.spm.spatial.preproc.tissue(3).tpm = {'/home/noah/spm12/tpm/TPM.nii,3'};
        matlabbatch{mbi}.spm.spatial.preproc.tissue(3).ngaus = 2;
        matlabbatch{mbi}.spm.spatial.preproc.tissue(3).native = [1 0];
        matlabbatch{mbi}.spm.spatial.preproc.tissue(3).warped = [0 0];
        matlabbatch{mbi}.spm.spatial.preproc.tissue(4).tpm = {'/home/noah/spm12/tpm/TPM.nii,4'};
        matlabbatch{mbi}.spm.spatial.preproc.tissue(4).ngaus = 2;
        matlabbatch{mbi}.spm.spatial.preproc.tissue(4).native = [1 0];
        matlabbatch{mbi}.spm.spatial.preproc.tissue(4).warped = [0 0];
        matlabbatch{mbi}.spm.spatial.preproc.tissue(5).tpm = {'/home/noah/spm12/tpm/TPM.nii,5'};
        matlabbatch{mbi}.spm.spatial.preproc.tissue(5).ngaus = 2;
        matlabbatch{mbi}.spm.spatial.preproc.tissue(5).native = [1 0];
        matlabbatch{mbi}.spm.spatial.preproc.tissue(5).warped = [0 0];
        matlabbatch{mbi}.spm.spatial.preproc.tissue(6).tpm = {'/home/noah/spm12/tpm/TPM.nii,6'};
        matlabbatch{mbi}.spm.spatial.preproc.tissue(6).ngaus = 2;
        matlabbatch{mbi}.spm.spatial.preproc.tissue(6).native = [0 0];
        matlabbatch{mbi}.spm.spatial.preproc.tissue(6).warped = [0 0];
        matlabbatch{mbi}.spm.spatial.preproc.warp.mrf = 1;
        matlabbatch{mbi}.spm.spatial.preproc.warp.cleanup = 1;
        matlabbatch{mbi}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
        matlabbatch{mbi}.spm.spatial.preproc.warp.affreg = 'mni';
        matlabbatch{mbi}.spm.spatial.preproc.warp.fwhm = 0;
        matlabbatch{mbi}.spm.spatial.preproc.warp.samp = 3;
        matlabbatch{mbi}.spm.spatial.preproc.warp.write = [1 1];
        matlabbatch{mbi}.spm.spatial.preproc.warp.vox = NaN;
        matlabbatch{mbi}.spm.spatial.preproc.warp.bb = [NaN NaN NaN;NaN NaN NaN];
    end


    % Normalization (use forward flow field from segmentation)
    if do_norm
        mbi = mbi + 1;
        matlabbatch{mbi}.spm.spatial.normalise.write.subj.def = cellstr(ns2MNI_flowfield);
        matlabbatch{mbi}.spm.spatial.normalise.write.subj.resample = cellstr([ct; pet]);
        matlabbatch{mbi}.spm.spatial.normalise.write.woptions.bb = bb; %[-90 -126 -72; 90 90 108]; % derived from TPM
        matlabbatch{mbi}.spm.spatial.normalise.write.woptions.vox = [1.5 1.5 1.5]; % derived from TPM
        matlabbatch{mbi}.spm.spatial.normalise.write.woptions.interp = 4;
        matlabbatch{mbi}.spm.spatial.normalise.write.woptions.prefix = 'w';
    end

    % Apply MNI pons mask to normalized PET
    if do_pons_mask
        mbi = mbi + 1;
        matlabbatch{mbi}.spm.util.imcalc.input = cellstr([wpet; MNI_PONS_MASK]);
        matlabbatch{mbi}.spm.util.imcalc.output = char(wpet_pons);
        matlabbatch{mbi}.spm.util.imcalc.outdir = cellstr(pet_dir);
        matlabbatch{mbi}.spm.util.imcalc.expression = 'i1.*i2';
        matlabbatch{mbi}.spm.util.imcalc.var = struct('name', {}, 'value', {});
        matlabbatch{mbi}.spm.util.imcalc.options.dmtx = 0;
        matlabbatch{mbi}.spm.util.imcalc.options.mask = 0;
        matlabbatch{mbi}.spm.util.imcalc.options.interp = 1;
        matlabbatch{mbi}.spm.util.imcalc.options.dtype = 4;
    end

    
    % Warp skull TPM to patient space using backwards transformation
    if do_iwarp_TPM 
        mbi = mbi + 1;
        matlabbatch{mbi}.spm.spatial.normalise.write.subj.def = cellstr(MNI2ns_flowfield);
        matlabbatch{mbi}.spm.spatial.normalise.write.subj.resample = cellstr(spm_TPM_skull); % 4th frame of TPM --> skull
        matlabbatch{mbi}.spm.spatial.normalise.write.woptions.bb = bb; %[-90 -126 -72; 90 90 108]; % derived from TPM
        matlabbatch{mbi}.spm.spatial.normalise.write.woptions.vox = [1.5 1.5 1.5]; % derived from TPM
        matlabbatch{mbi}.spm.spatial.normalise.write.woptions.interp = 4;
        matlabbatch{mbi}.spm.spatial.normalise.write.woptions.prefix = 'iw'; % inverse warped        
    end
    
    % run batch
    save("matlabbatch1.mat", "matlabbatch");
    if ~debug && ~isempty(matlabbatch)
        spm_jobman('initcfg');
        spm_jobman('run',matlabbatch);
    end

    % Reset batch
    matlabbatch = [];
    mbi = 0;

    % move iw_TPM from SPM12 to sub_folder
    if do_iwarp_TPM
        cmd = sprintf('mv %s %s -v', iw_spm_TPM_skull, iw_tpm);
        system(cmd);
    end
    
    % Binarize TPM in patient space
    if do_iwarp_TPM
        mbi = mbi + 1;
        matlabbatch{mbi}.spm.util.imcalc.input = cellstr(strcat(iw_tpm, ',4'));
        matlabbatch{mbi}.spm.util.imcalc.output = char(iw_tpmb05); %  has only one frame
        matlabbatch{mbi}.spm.util.imcalc.outdir = cellstr(sub_dir);
        matlabbatch{mbi}.spm.util.imcalc.expression = 'i1>0.5';
        matlabbatch{mbi}.spm.util.imcalc.var = struct('name', {}, 'value', {});
        matlabbatch{mbi}.spm.util.imcalc.options.dmtx = 0;
        matlabbatch{mbi}.spm.util.imcalc.options.mask = 0;
        matlabbatch{mbi}.spm.util.imcalc.options.interp = 1;
        matlabbatch{mbi}.spm.util.imcalc.options.dtype = 4;
    end  

     % Apply TPM and binarized TPM to PET and CT 
     if do_TPM_mask       
        mbi = mbi + 1;
        matlabbatch{mbi}.spm.util.imcalc.input = cellstr([strcat(iw_tpm,',4') ct]');
        matlabbatch{mbi}.spm.util.imcalc.output = char(ct_skullTPM);
        matlabbatch{mbi}.spm.util.imcalc.outdir = cellstr(ct_dir); % will be ignored
        matlabbatch{mbi}.spm.util.imcalc.expression = 'i1.*i2'; % so we dont get weird negative values
        matlabbatch{mbi}.spm.util.imcalc.var = struct('name', {}, 'value', {});
        matlabbatch{mbi}.spm.util.imcalc.options.dmtx = 0;
        matlabbatch{mbi}.spm.util.imcalc.options.mask = 0;
        matlabbatch{mbi}.spm.util.imcalc.options.interp = 1;
        matlabbatch{mbi}.spm.util.imcalc.options.dtype = 4;

        mbi = mbi + 1;
        matlabbatch{mbi} = matlabbatch{mbi-1};
        matlabbatch{mbi}.spm.util.imcalc.input = cellstr([iw_tpmb05 ct]');
        matlabbatch{mbi}.spm.util.imcalc.output = char(ct_skullTPMb05);
        
        mbi = mbi + 1;
        matlabbatch{mbi} = matlabbatch{mbi-1};
        matlabbatch{mbi}.spm.util.imcalc.input = cellstr([strcat(iw_tpm,',4') pet]');
        matlabbatch{mbi}.spm.util.imcalc.output = char(pet_skullTPM);
        matlabbatch{mbi}.spm.util.imcalc.expression = 'i1.*i2';
       
        mbi = mbi + 1;
        matlabbatch{mbi} = matlabbatch{mbi-1};
        matlabbatch{mbi}.spm.util.imcalc.input = cellstr([iw_tpmb05 pet]');
        matlabbatch{mbi}.spm.util.imcalc.output = char(pet_skullTPMb05);
        matlabbatch{mbi}.spm.util.imcalc.expression = 'i1.*i2';
     end

     % Warp mean CT skull mask to patient space
     if do_iwarp_meanCT 
         mbi = mbi + 1;
        matlabbatch{mbi}.spm.spatial.normalise.write.subj.def = cellstr(MNI2ns_flowfield);
        matlabbatch{mbi}.spm.spatial.normalise.write.subj.resample = cellstr(MEAN_CT_SKULL);
        matlabbatch{mbi}.spm.spatial.normalise.write.woptions.bb = bb; %[-90 -126 -72; 90 90 108]; % derived from TPM
        matlabbatch{mbi}.spm.spatial.normalise.write.woptions.vox = [1.5 1.5 1.5]; % derived from TPM
        matlabbatch{mbi}.spm.spatial.normalise.write.woptions.interp = 4;
        matlabbatch{mbi}.spm.spatial.normalise.write.woptions.prefix = 'iw'; % inverse warped  
     end      

   % run batch
    save("matlabbatch2.mat", "matlabbatch");
    if ~debug && ~isempty(matlabbatch)
        spm_jobman('initcfg');
        spm_jobman('run',matlabbatch);
    end

     % Reset batch
    matlabbatch = [];
    mbi = 0;

    % move warped meanCT to subject folder
    if do_iwarp_meanCT
        cmd = sprintf('mv %s %s -v', iwMEAN_CT_SKULL, mean_ct_skull_mask);
        system(cmd);
    end
    
    % Apply meanCT skull mask to PET and CT
    if do_meanCT_mask 
        mbi = mbi + 1;
        matlabbatch{mbi}.spm.util.imcalc.input = cellstr([mean_ct_skull_mask ct]');
        matlabbatch{mbi}.spm.util.imcalc.output = char(ct_skullmeanCT750);
        matlabbatch{mbi}.spm.util.imcalc.outdir = cellstr(ct_dir); % will be ignored
        matlabbatch{mbi}.spm.util.imcalc.expression = 'i1.*i2';
        matlabbatch{mbi}.spm.util.imcalc.var = struct('name', {}, 'value', {});
        matlabbatch{mbi}.spm.util.imcalc.options.dmtx = 0;
        matlabbatch{mbi}.spm.util.imcalc.options.mask = 0;
        matlabbatch{mbi}.spm.util.imcalc.options.interp = 1;
        matlabbatch{mbi}.spm.util.imcalc.options.dtype = 4;

        mbi = mbi + 1;
        matlabbatch{mbi} = matlabbatch{mbi-1};
        matlabbatch{mbi}.spm.util.imcalc.input = cellstr([mean_ct_skull_mask pet]'); % use MNI masks to define vox size etc.
        matlabbatch{mbi}.spm.util.imcalc.output = char(pet_skullmeanCT750);
    end

    % run batch
    save("matlabbatch1.mat", "matlabbatch");
    if ~debug && ~isempty(matlabbatch)
        spm_jobman('initcfg');
        spm_jobman('run',matlabbatch);
    end

    % Reset batch
    fprintf("done.\n\n");
    matlabbatch = [];
    mbi = 0;
end

% Create mean CT
if do_meanCT
    matlabbatch = [];
    all_wCTs = [];

    % Collect all warped CTs
    for i = 1:numel(SUBS)
        sub = SUBS(i);
        sub_dir = fullfile(DATA_DIR, patients.folder(sub));
        wct     = char(fullfile(sub_dir, 'ct', WCT_TEMPL));
        all_wCTs = char(all_wCTs, wct);
    end

    fprintf("\nCollected %d wCTs\n", size(all_wCTs,1));

    % Calculate the mean
    matlabbatch{1}.spm.util.imcalc.input = cellstr(all_wCTs);
    matlabbatch{1}.spm.util.imcalc.output = char(MEAN_CT);
    matlabbatch{1}.spm.util.imcalc.outdir = cellstr(DATA_DIR);
    matlabbatch{1}.spm.util.imcalc.expression = 'mean(X)';
    matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
    matlabbatch{1}.spm.util.imcalc.options.dmtx = 1;
    matlabbatch{1}.spm.util.imcalc.options.mask = 0;
    matlabbatch{1}.spm.util.imcalc.options.interp = 1;
    matlabbatch{1}.spm.util.imcalc.options.dtype = 4;

    % Obtain skull mask from mean CT
    matlabbatch{2}.spm.util.imcalc.input = cellstr(MEAN_CT);
    matlabbatch{2}.spm.util.imcalc.output = char(MEAN_CT_SKULL);
    matlabbatch{2}.spm.util.imcalc.outdir = cellstr(sub_dir);
    matlabbatch{2}.spm.util.imcalc.expression = 'i1>750';
    matlabbatch{2}.spm.util.imcalc.var = struct('name', {}, 'value', {});
    matlabbatch{2}.spm.util.imcalc.options.dmtx = 0;
    matlabbatch{2}.spm.util.imcalc.options.mask = 0;
    matlabbatch{2}.spm.util.imcalc.options.interp = 1;
    matlabbatch{2}.spm.util.imcalc.options.dtype = 4;

    % run batch
    save("matlabbatch1.mat", "matlabbatch");
    if ~debug && ~isempty(matlabbatch)
        spm_jobman('initcfg');
        spm_jobman('run',matlabbatch);
    end
end




