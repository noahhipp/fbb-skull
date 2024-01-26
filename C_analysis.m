function D_analysisV2

% Housekeeping constants
SCRIPT_LOCATION     = fileparts(mfilename("fullpath"));
BASE_DIR            = fullfile(SCRIPT_LOCATION, "..");
DATA_DIR            = fullfile(BASE_DIR, 'data');
SPM_DIR             = fileparts(which('spm'));

PET_DIR_TEMPL       = 'pet'; % single quotes --> char --> indexable
CT_DIR_TEMPL        = 'ct';

% PET templates
PET_pons_TEMPL      = 'wpet01_pons.nii';

PET_TEMPL           = 'pet01.nii';
PET_meanCT750_TEMPL = 'pet01_skullmeanCT750.nii';
PET_skullTPM_TEMPL = 'pet01_skullTPM.nii';
PET_skullTPMb05_TEMPL = 'pet01_skullTPMb05.nii';

% CT templates
CT_TEMPL           = 'ct01.nii';
CT_meanCT750_TEMPL = 'ct01_skullmeanCT750.nii';
CT_skullTPM_TEMPL = 'ct01_skullTPM.nii';
CT_skullTPMb05_TEMPL = 'ct01_skullTPMb05.nii';

% Masks
MASKS = {...
    'skullmeanCT750',...
    'skullTPM',...
    'skullTPMb05'};

% to avoid using regexps for finding folders
PATIENT_FILE = fullfile(BASE_DIR, "patients.mat");
load(PATIENT_FILE, "patients");

SUBS = [1:44];
for i = 1:numel(SUBS)
    
    % Subject specific paths
    sub                     = SUBS(i);
    sub_dir                 = fullfile(DATA_DIR, patients.folder(sub));
    fprintf("Preparing first batch for %s\n... ", sub_dir);
    ct_dir                  = fullfile(sub_dir, CT_DIR_TEMPL);   
    pet_dir                 = fullfile(sub_dir, PET_DIR_TEMPL);

    % PETs
    pet                     = fullfile(pet_dir, PET_TEMPL);
    wpet_pons                = fullfile(pet_dir, PET_pons_TEMPL);
    
    % CTs
    ct                     = fullfile(ct_dir, CT_TEMPL);


    % Calculate pons signal    
    v_pons = spm_vol(char(wpet_pons));
    y_pons = spm_read_vols(v_pons);
    mean_pa = mean(y_pons(y_pons > 0),"all");
    median_pa = median(y_pons(y_pons > 0),"all");
    patients.mean_pa(sub) = mean_pa;
    patients.median_pa(sub) = median_pa;
    save(PATIENT_FILE, "patients");
    fprintf("\nMean pons activation: %.6f\n", mean_pa);
    fprintf("Median pons activation: %.6f. Ration mean/median: %.3f\n", median_pa, mean_pa/median_pa);    

    for j = 1:numel(MASKS)
        mask = MASKS{j};

        % Grab CT
        [~,ct_name,ext] = fileparts(ct);
        masked_ct = fullfile(ct_dir, strcat(ct_name, '_', mask, ext));
        v_ct = spm_vol(char(masked_ct));
        y_ct = spm_read_vols(v_ct);

        % Grab PET
        [~,pet_name,ext] = fileparts(pet);
        masked_pet = fullfile(pet_dir, strcat(pet_name, '_', mask, ext));
        v_pet = spm_vol(char(masked_pet));
        y_pet = spm_read_vols(v_pet); 


        % PET: calculate
        % mean uptake
        patients.(['mean-uptake_' mask])(sub) = mean(y_pet, 'all');
        patients.(['hottest10-uptake_' mask])(sub) = ...
            mean(y_pet(y_pet > prctile(y_pet, 90, "all")), 'all');

        % scale with mean pons post hoc
        % scale with median pons post hoc

        % CT: calculate
        patients.(['mean-density_' mask])(sub) = mean(y_ct, 'all');
    end
end

save(PATIENT_FILE, "patients");
