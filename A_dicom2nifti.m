function A_dicom2nifti
% Converts dicom files to NIfTI (Neuroimaging Informatics Technology
% Initiative) data format and centers coordinate system on centroid

% Housekeeping constants)
SCRIPT_LOCATION     = fileparts(mfilename("fullpath"));
BASE_DIR            = fullfile(SCRIPT_LOCATION, "..");
DATA_DIR            = fullfile(BASE_DIR, 'data');

PET_DIR_TEMPL       = '*late_detail'; % single quotes --> char --> indexable
CT_DIR_TEMPL        = '*late_aCT';

MODALITIES          = {"ct", "pet"};

SUBS = [1:44];

do_dcm_convert  = 1;

% Collect patient file
PATIENT_FILE = fullfile(BASE_DIR, "patients.mat");
load(PATIENT_FILE, "patients");

% Subject loop start
for i = 1:size(SUBS,2)
    sub = SUBS(i);
    name = patients.folder(sub);
    sub_dir = fullfile(DATA_DIR, name);
    fprintf("\n----------------------\ndoing %s\n", name);

    % Lists all folders (except "ct" and "pet") in sub_dir to iterate over
    sub_source_dirs = dir_folders_only(sub_dir);

    if do_dcm_convert

        % reset job counter
        gi = 1;

        % Image loop start
        for j = 1:numel(sub_source_dirs)

            % determine whether ct else pet
            if contains(sub_source_dirs{j}, CT_DIR_TEMPL(2:end)) % avoid the asterix
                isct = 1;
            modality = MODALITIES{1};
                patients.ct_imported(sub) = patients.ct_imported(sub) + 1; 
                fprintf("processing CT\n");
            else
                isct = 0;
                modality = MODALITIES{2};
                patients.pet_imported(sub) = patients.pet_imported(sub) + 1;
                fprintf("processing PET\n");
            end

            % obtain source and target dir
            source_dir = fullfile(sub_dir, sub_source_dirs{j});
            target_dir = fullfile(sub_dir, modality);
            if ~exist(target_dir, "dir")
                mkdir(target_dir);
                fprintf("created %s\n", target_dir);
            end

            % if ct we check header and obtain patient information
            if isct
                % collect dummy file to read header from
                df = dir(fullfile(source_dir,"*.dcm")).name;
                df = fullfile(source_dir, df);

                % read header
                hdr = spm_dicom_headers(df);
                hdr = hdr{:};

                % check parameters
                if (hdr.ExposureTime == 600 && hdr.XRayTubeCurrent == 25 ...
                        && hdr.Exposure == 15)
                    fprintf("%s CT parameters look good.\n", name);
                else
                    warning("%s CT parameters not correct.\n", name);
                end

                % obtain patient and examination info
                patients.age(sub) = str2double(hdr.PatientAge(2:3));
                patients.height(sub) = hdr.PatientSize;
                patients.weight(sub) = hdr.PatientWeight;
                patients.sex(sub)    = strip(hdr.PatientSex); % get rid of whitespace
                patients.date_birth(sub) = hdr.PatientBirthDate;
                patients.date_examination(sub) = datetime(hdr.AcquisitionDateTime,...
                    "InputFormat","yyyyMMddHHmmss.SSS");

               
            end % end ct parameters check

            % specify spm job
            files = spm_select('FPList', source_dir, '.dcm$');
            matlabbatch{gi}.spm.util.import.dicom.data = cellstr(files);
            matlabbatch{gi}.spm.util.import.dicom.outdir = cellstr(target_dir);
            matlabbatch{gi}.spm.util.import.dicom.root             = 'flat';
            matlabbatch{gi}.spm.util.import.dicom.protfilter       = '.*';
            matlabbatch{gi}.spm.util.import.dicom.convopts.format  = 'nii';
            matlabbatch{gi}.spm.util.import.dicom.convopts.meta    = 0;
            matlabbatch{gi}.spm.util.import.dicom.convopts.icedims = 0;
            gi = gi + 1; % increment job counter
        end % image loop
    end % if do_dicom_convert

    % process matlabbatch
    save matlabbatch matlabbatch
    spm_jobman('initcfg');
    spm_jobman('run',matlabbatch);
    clear matlabbatch;

    % rename fresh niftis according to their parent dir and center their
    % coordinate system of the centroid (center of mass)
    for j = 1:numel(MODALITIES)
        modality            = MODALITIES{j};
        modality_counter    = 1;
        [modality_files, modality_dir] = ...
            dir_files_only(fullfile(sub_dir, modality));
        
        for k = 1:numel(modality_files)
            
            % rename files
            s = modality_files(k);
            d = fullfile(modality_dir, ...
                sprintf("%s%02d.nii", modality, modality_counter));
            movefile(s,d);
            fprintf("renamed: %s --> %s\n", s,d);

            % center coordinate system
            origin2COM(d);
        end % file loop end        
    end % modality loop end   

     % save updated patients file
    save(PATIENT_FILE, "patients");

end % subject loop


function sfn = dir_folders_only(d)
files = dir(d);
dir_flags = [files.isdir];
sf = files(dir_flags);
sfn = string({sf(3:end).name});
sfn(sfn == "pet" | sfn == "ct") = [];

function [full_file_names, folder] = dir_files_only(d)
all = dir(d);
dir_flags = [all.isdir];
files = all(~dir_flags);
file_names = string({files.name});
folder = files(1).folder;
full_file_names = fullfile(folder, file_names);

