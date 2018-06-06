
classdef Core_Utils < handle
    properties
    end
    
    methods (Static)
        function idx = findMO(find_list, to_find_el)
            % find the postion of the elements of to_find_el into find_list
            % find list should have unique elements
            idx = zeros(size(to_find_el));
            for i = 1: length(to_find_el)
                idx(i) = find(find_list == to_find_el(i),1);
            end
        end
        
        function num = code3Char2Num(str3)
            % Convert a 3 char string into a numeric value (float)
            % SYNTAX
            %   num = Core_Utils.code3ch2Num(str3);
            
            num = str3(:,1:3) * [2^16 2^8 1]';
        end
        
        function str3 = num2Code3Char(num)
            % Convert a numeric value (float) of a 3 char string
            % SYNTAX
            %   str3 = Core_Utils.num2Code3ch(num)
            str3 = char(zeros(numel(num), 3));
            str3(:,1) = char(floor(num / 2^16));
            num = num - str3(:,1) * 2^16;
            str3(:,2) = char(floor(num / 2^8));
            num = num - str3(:,2) * 2^8;
            str3(:,3) = char(num);
        end
        
        function num = code4Char2Num(str4)
            % Convert a 4 char string into a numeric value (float)
            % SYNTAX
            %   num = Core_Utils.code4ch2Num(str4);
            
            num = str4(:,1:4) * [2^24 2^16 2^8 1]';
        end
        
        function str4 = num2Code4Char(num)
            % Convert a numeric value (float) of a 4 char string
            % SYNTAX
            %   str4 = Core_Utils.num2Code4Char(num)
            str4 = char(zeros(numel(num), 4));
            str4(:,1) = char(floor(num / 2^24));
            num = num - str4(:,1) * 2^24;
            str4(:,2) = char(floor(num / 2^16));
            num = num - str4(:,2) * 2^16;
            str4(:,3) = char(floor(num / 2^8));
            num = num - str4(:,3) * 2^8;
            str4(:,4) = char(num);
        end
        
        function str4 = unique4ch(str4)
            % Perform unique on an array of 4 char codes
            %
            % SYNTAX
            %   str4 = Core_Utilis.unique4ch(str4)
            str4 = Core_Utils.num2Code4Char(unique(Core_Utils.code4Char2Num(str4)));
        end
        
        function str3 = unique3ch(str3)
            % Perform unique on an array of 3 char codes
            %
            % SYNTAX
            %   str3 = Core_Utilis.unique3ch(str3)
            str3 = Core_Utils.num2Code3Char(unique(Core_Utils.code3Char2Num(str3)));
        end
        
        function [antenna_PCV] = readAntennaPCV(filename, antmod, date_limits)
            % SYNTAX:
            %   [antPCV] = this.readAntennaPCV(filename, antmod, date_start, date_stop);
            %
            % INPUT:
            %   filename    = antenna phase center offset/variation file
            %   antmod      = cell-array containing antenna model strings
            %   date_limits = in GPS_Time to filter useful data (matlab format preferred)
            %
            % OUTPUT:
            %   antenna_PCV (see description below)
            %
            % DESCRIPTION:
            %   Extracts antenna phase center offset/variation values from a PCO/PCV file in ATX format.
            %
            % RESOURCES:
            %   ftp://igs.org/pub/station/general/antex14.txt
            %
            % antenna_PCV struct definition
            % antenna_PCV.name           : antenna name (with radome code)
            % antenna_PCV.n_frequency    : number of available frequencies
            % antenna_PCV.frequency_name : array with name of available frequencies ({'G01';'G02';'R01',...})
            % antenna_PCV.frequency      : array with list of frequencies (carrier number) corresponding to the frequencies name ({'1';'2';'1',...})
            % antenna_PCV.sys            : array with code id of the system constellation of each frequency (1: GPS, 2: GLONASS, ...)
            % antenna_PCV.sysfreq        : array with codes of the system constellation and carrier of each frequency (11: GPS L1, 12: GPS L2, 21: GLONASS L1, ...)
            % antenna_PCV.offset         : ENU (receiver) or NEU (satellite) offset (one array for each frequency)
            % antenna_PCV.dazi           : increment of the azimuth (0.0 for non-azimuth-dependent phase center variations)
            % antenna_PCV.zen1           : Definition of the grid in zenith angle: minimum zenith angle
            % antenna_PCV.zen2           : Definition of the grid in zenith angle: maximum zenith angle
            % antenna_PCV.dzen           : Definition of the grid in zenith angle: increment of the zenith angle
            % antenna_PCV.tableNOAZI     : PCV values for NOAZI, in a cell array with a vector for each frequency [m]
            % antenna_PCV.tablePCV       : PCV values elev/azim depentend, in a cell array with a matrix for each frequency [m]
            % antenna_PCV.tablePCV_zen   : zenith angles corresponding to each column of antenna_PCV.tablePCV
            % antenna_PCV.tablePCV_azi   : azimutal angles corresponding to each row of antenna_PCV.tablePCV
            
            log = Logger.getInstance();
            
            for m = numel(antmod) : -1 : 1
                antenna_PCV(m) = struct('name', antmod{m}, ...
                    'sat_type',[] ,...
                    'n_frequency', 0, ...
                    'available', 0, ...
                    'type', '', ...
                    'dazi', 0, ...
                    'zen1', 0, ...
                    'zen2', 0, ...
                    'dzen', 0, ...
                    'offset', [], ...
                    'frequency_name', [], ...
                    'frequency', [], ...
                    'sys', [], ...
                    'sysfreq', [], ...
                    'tableNOAZI', [], ...
                    'tablePCV_zen', [], ...
                    'tablePCV_azi', [], ...
                    'tablePCV', []);
            end
            antenna_found = zeros(length(antmod),1);
            
            % for each PCV file
            for file_pcv = 1 : size(filename, 1)
                if sum(antenna_found) < length(antmod)
                    if (~isempty(filename))
                        fid = fopen(char(filename(file_pcv, :)),'r');
                        if (fid ~= -1)
                            atx_file = textscan(fid,'%s','Delimiter', '\n', 'whitespace', '');
                            atx_file = atx_file{1};
                            fclose(fid);
                            
                            found = 0;
                            format = 0;
                            % get format (1: ATX, 2: Bernese 5.0, 3: Bernese 5.2)
                            l = 1;
                            line = atx_file{l};
                            if ~isempty(strfind(line, 'ANTEX VERSION / SYST'))
                                format = 1;
                            end
                            if ~isempty(strfind(line, 'MODEL NAME:'))
                                format = 2;
                            end
                            if ~isempty(strfind(line, 'ANTENNA PHASE CENTER VARIATIONS DERIVED FROM ANTEX FILE'))
                                format = 3;
                            end
                            
                            switch format
                                % ATX
                                case 1
                                    flag_stop = 0;
                                    ant_char = strcat(antmod{:});
                                    while (l < numel(atx_file) && found < length(antmod) && ~flag_stop)
                                        % go to the next antenna
                                        line = atx_file{l};
                                        while (l < numel(atx_file)-1) && ((length(line) < 76) || isempty(strfind(line(61:76),'START OF ANTENNA')))
                                            l = l + 1; line = atx_file{l};
                                        end
                                        l = l + 1; line = atx_file{l};
                                        
                                        if ~isempty(strfind(line,'TYPE / SERIAL NO')) %#ok<*STREMP> % antenna serial number
                                            if (nargin == 2) % receiver
                                                id_ant = strfind(ant_char,line(1:20));
                                                sat_type=[];
                                                 
                                            else
                                                id_ant = strfind(ant_char, line(21:23));
                                                sat_type=strtrim(line(1:20));
                                            end
                                            if ~isempty(id_ant)
                                                if (nargin == 2) % receiver
                                                    m = (id_ant - 1) / 20 + 1; % I'm reading the antenna
                                                else
                                                    m = (id_ant - 1) / 3 + 1; % I'm reading the antenna
                                                end
                                                
                                                if ~(antenna_PCV(m(1)).available)
                                                    
                                                    for a = 1:length(m)
                                                        log.addMessage(sprintf('Reading antenna %d => %s', m(a), antmod{m(a)}),100);
                                                    end
                                                    
                                                    invalid_date = 0;
                                                    
                                                    validity_start = [];
                                                    validity_end   = [];
                                                    
                                                    l_start = l; % line at the beginng of the antenna section
                                                    % look for "VALID FROM" and "VALID UNTIL" lines (if satellite antenna)
                                                    if (nargin > 2)
                                                        while (isempty(strfind(line,'VALID FROM')))
                                                            l = l + 1; line = atx_file{l};
                                                        end
                                                        validity_start = [str2num(line(3:6)) str2num(line(11:12)) str2num(line(17:18)) str2num(line(23:24)) str2num(line(29:30)) str2num(line(34:43))]; %#ok<*ST2NM>
                                                        l = l + 1; line = atx_file{l};
                                                        if (strfind(line, 'VALID UNTIL')) %#ok<*STRIFCND>
                                                            validity_end = [str2num(line(3:6)) str2num(line(11:12)) str2num(line(17:18)) str2num(line(23:24)) str2num(line(29:30)) str2num(line(34:43))];
                                                        else
                                                            validity_end = Inf;
                                                        end
                                                    end
                                                    
                                                    if (~isempty(validity_start)) % satellite antenna
                                                        if ~(date_limits.first.getMatlabTime() > datenum(validity_start) && (date_limits.last.getMatlabTime() < datenum(validity_end)))
                                                            invalid_date = 1;
                                                            antenna_PCV(m(1)).n_frequency = 0;
                                                            if isinf(validity_end)
                                                                log.addMessage(sprintf(' - out of range -> (%s : %s) not after %s', date_limits.first.toString(), date_limits.last.toString(), datestr(validity_start)), 100)
                                                            else
                                                                log.addMessage(sprintf(' - out of range -> (%s : %s) not intersecting (%s : %s)', date_limits.first.toString(), date_limits.last.toString(), datestr(validity_start), datestr(validity_end)), 100)
                                                            end
                                                        end
                                                    else  %receiver antenna
                                                    end
                                                    
                                                    if ~(invalid_date) % continue parsing
                                                        for a = 1:length(m)
                                                            log.addMessage(sprintf('Found a valid antenna %s', antmod{m(a)}), 50);
                                                        end
                                                        l = l_start;
                                                        
                                                        % get TYPE
                                                        antenna_PCV(m(1)).type = line(1:20);
                                                        
                                                        % PUT SATELLITE
                                                        antenna_PCV(m(1)).sat_type = sat_type;
                                                        
                                                        % get DAZI
                                                        while (isempty(strfind(line,'DAZI')))
                                                            l = l + 1; line = atx_file{l};
                                                        end
                                                        antenna_PCV(m(1)).dazi=sscanf(line(1:8),'%f');
                                                        
                                                        % get ZEN1 / ZEN2 / DZEN
                                                        while (isempty(strfind(line,'ZEN1 / ZEN2 / DZEN')))
                                                            l = l + 1; line = atx_file{l};
                                                        end
                                                        antenna_PCV(m(1)).zen1 = sscanf(line(1:8),'%f');
                                                        antenna_PCV(m(1)).zen2 = sscanf(line(9:14),'%f');
                                                        antenna_PCV(m(1)).dzen = sscanf(line(15:20),'%f');
                                                        
                                                        % get FREQUENCIES
                                                        while (isempty(strfind(line,'# OF FREQUENCIES')))
                                                            l = l + 1; line = atx_file{l};
                                                        end
                                                        antenna_PCV(m(1)).n_frequency=sscanf(line(1:8),'%d');
                                                        antenna_PCV(m(1)).offset = zeros(1,3,antenna_PCV(m(1)).n_frequency);
                                                        
                                                        %get information of each frequency
                                                        frequencies_found = 0;
                                                        
                                                        while frequencies_found < antenna_PCV(m(1)).n_frequency
                                                            while (isempty(strfind(line,'START OF FREQUENCY')))
                                                                l = l + 1; line = atx_file{l};
                                                            end
                                                            frequencies_found=frequencies_found+1;
                                                            antenna_PCV(m(1)).frequency_name(frequencies_found,:) = sscanf(line(4:6),'%s');
                                                            antenna_PCV(m(1)).frequency(frequencies_found) = sscanf(line(6),'%d');
                                                            
                                                            switch sscanf(line(4),'%c')
                                                                case 'G'
                                                                    antenna_PCV(m(1)).sys(frequencies_found) = 1;
                                                                case 'R'
                                                                    antenna_PCV(m(1)).sys(frequencies_found) = 2;
                                                                case 'E'
                                                                    antenna_PCV(m(1)).sys(frequencies_found) = 3;
                                                                case 'J'
                                                                    antenna_PCV(m(1)).sys(frequencies_found) = 4;
                                                                case 'C'
                                                                    antenna_PCV(m(1)).sys(frequencies_found) = 5;
                                                                case 'I'
                                                                    antenna_PCV(m(1)).sys(frequencies_found) = 6;
                                                                case 'S'
                                                                    antenna_PCV(m(1)).sys(frequencies_found) = 7;
                                                            end
                                                            antenna_PCV(m(1)).sysfreq(frequencies_found) = antenna_PCV(m(1)).sys(frequencies_found) * 10 + antenna_PCV(m(1)).frequency(frequencies_found);
                                                            
                                                            while (isempty(strfind(line,'NORTH / EAST / UP')))
                                                                l = l + 1; line = atx_file{l};
                                                            end
                                                            if (~isempty(validity_start)) %satellite antenna
                                                                antenna_PCV(m(1)).offset(1,1:3,frequencies_found) = [sscanf(line(1:10),'%f'),sscanf(line(11:20),'%f'),sscanf(line(21:30),'%f')].*1e-3; % N,E,U
                                                                if (frequencies_found == antenna_PCV(m(1)).n_frequency)
                                                                    antenna_PCV(m(1)).available = 1;
                                                                end
                                                            else
                                                                antenna_PCV(m(1)).offset(1,1:3,frequencies_found) = [sscanf(line(11:20),'%f'),sscanf(line(1:10),'%f'),sscanf(line(21:30),'%f')].*1e-3; %E,N,U
                                                                antenna_PCV(m(1)).available = 1;
                                                            end
                                                            
                                                            number_of_zenith=(antenna_PCV(m(1)).zen2-antenna_PCV(m(1)).zen1)/antenna_PCV(m(1)).dzen+1;
                                                            if antenna_PCV(m(1)).dazi~=0
                                                                number_of_azimuth=(360-0)/antenna_PCV(m(1)).dazi+1;
                                                            else
                                                                number_of_azimuth=0;
                                                            end
                                                            
                                                            % NOAZI LINE
                                                            l = l + 1; line = atx_file{l};
                                                            antenna_PCV(m(1)).tableNOAZI(1,:,frequencies_found)=sscanf(line(9:end),'%f')'.*1e-3;
                                                            antenna_PCV(m(1)).tablePCV_zen(1,1:number_of_zenith,1)=antenna_PCV(m(1)).zen1:antenna_PCV(m(1)).dzen:antenna_PCV(m(1)).zen2;
                                                            
                                                            % TABLE AZI/ZEN DEPENDENT
                                                            if number_of_azimuth ~= 0
                                                                antenna_PCV(m(1)).tablePCV_azi(1,1:number_of_azimuth,1)=NaN(number_of_azimuth,1);
                                                                antenna_PCV(m(1)).tablePCV(:,:,frequencies_found)=NaN(number_of_azimuth,number_of_zenith);
                                                            else
                                                                antenna_PCV(m(1)).tablePCV_azi(1,1:number_of_azimuth,1)=NaN(1,1);
                                                                antenna_PCV(m(1)).tablePCV(:,:,frequencies_found)=NaN(1,number_of_zenith);
                                                            end
                                                            
                                                            l = l + 1; line = atx_file{l};
                                                            if (isempty(strfind(line,'END OF FREQUENCY')))
                                                                tablePCV=zeros(number_of_azimuth,number_of_zenith);
                                                                for i=1:number_of_azimuth
                                                                    tablePCV(i,:)=sscanf(line(9:end),'%f')'.*1e-3;
                                                                    l = l + 1; line = atx_file{l};
                                                                end
                                                                antenna_PCV(m(1)).tablePCV(:,:,frequencies_found)=tablePCV;
                                                                antenna_PCV(m(1)).tablePCV_azi(:,1:number_of_azimuth,1)=0:antenna_PCV(m(1)).dazi:360;
                                                            end
                                                            if number_of_azimuth == 0
                                                                antenna_PCV(m(1)).tablePCV(:,:,frequencies_found)=NaN(1,number_of_zenith);
                                                            end
                                                        end
                                                        found = found + length(m);
                                                        antenna_found(m) = 1;
                                                        for a = 2 : length(m)
                                                            antenna_PCV(m(a)) = antenna_PCV(m(1));
                                                        end
                                                    else % invalid_date
                                                        while (isempty(strfind(line,'END OF ANTENNA')))
                                                            l = l + 1; line = atx_file{l};
                                                        end
                                                    end
                                                elseif (nargin > 2) && strcmp(line(41:44),'    ')
                                                    flag_stop = true;
                                                    log.addMessage('There are no more antenna!!!',100);
                                                end
                                            end
                                        end
                                    end
                                case 2
                                    
                                    
                                case 3
                                    
                                    
                                case 0
                                    
                            end
                        else
                            log.addWarning('PCO/PCV file not loaded.\n');
                        end
                    else
                        log.addWarning('PCO/PCV file not loaded.\n');
                    end
                end
            end
            
            idx_not_found = find(~antenna_found);
            if ~isempty(idx_not_found)
                w_msg = sprintf('The PCO/PCV model for the following antennas has not been found,\nsome models are missing or not defined at the time of processing');
                for a = 1 : length(idx_not_found)
                    w_msg = sprintf('%s\n -  antenna model for "%s" is missing', w_msg, cell2mat(antmod(idx_not_found(a))));
                end
                log.addWarning(w_msg);
            end
        end
        
        function [status] = downloadHttpTxtRes(filename, out_dir)
            log = Logger.getInstance();
            fnp = File_Name_Processor();
            try
                options = weboptions;
                options.ContentType = 'text';
                options.Timeout = 15;
                [remote_location, filename, ext] =fileparts(filename);
                filename = [filename ext];
                log.addMessage(log.indent(sprintf('downloading %s ...',filename)));
                txt = webread(['http://' remote_location filesep filename], options);
                if ~isempty(out_dir) && ~exist(out_dir, 'dir')
                    mkdir(out_dir);
                end
                fid = fopen(fnp.checkPath([out_dir, filesep filename]),'w');
                if fid < 0
                    log.addError(sprintf('Writing of %s failed', fnp.checkPath([out_dir, filesep filename])));
                else
                    fprintf(fid,'%s',txt);
                    fclose(fid);
                end
                status = true;
                log.addMessage(' Done');
            catch
                status = false;
            end
        end
        
        function [status] = checkHttpTxtRes(filename)
            if isunix() || ismac()
                 [resp, txt] = system(['curl --head ' filename]);
                 if strfind(txt,'HTTP/1.1 200 OK')
                     status = true;
                 else
                     status = false;
                 end
            else
                status = true; % !!! to be implemented
                
            end
        end
        
        function station_list = getStationList(dir_path, file_ext)
            % Get the list of stations present in a folder (with keys substituted)
            %
            % SYNTAX
            %   station_list = Core_Utilis.getStationList(dir_path)
            
            try
                % Calling dos is faster than dir with large directories
                if isunix
                    [~, d] = dos(['ls ' dir_path]); dir_list = strsplit(d);
                else
                    [~, d] = dos(['dir ' dir_path]); dir_list = strsplit(d);
                end
            catch
                dir_list = dir(dir_path);
                dir_list = {dir_list.name};
            end                                   
            
            % search for station files STAT${DOY}${S}${QQ}.${YY}
            if nargin == 1
                file_ext = '.';
            else
                file_ext = ['[' file_ext ']'];
            end
            file_list = [];
            for d = 1 : numel(dir_list)
                file_name_len = numel(dir_list{d});
                if (file_name_len == 14) && ~isempty(regexp(dir_list{d}, ['.{4}[0-9]{3}.{1}[0-9]{2}[\.]{1}[0-9]{2}' file_ext '{1}'], 'once'))
                    file_list = [file_list; [dir_list{d}(1:4) '${DOY}${S}${QQ}.${YY}' dir_list{d}(end)]]; %#ok<AGROW>
                    %file_list = [file_list; dir_list{d}(1:4)];
                end                    
            end
            station_list = {};
            if size(file_list, 2) > 1
                station_num = Core_Utils.code4Char2Num(file_list(:,1:4));
                station_name = unique(station_num);
                for s = 1 : numel(station_name)
                    station_list = [station_list; {file_list(find(station_num == station_name(s), 1, 'first'),:)}]; %#ok<AGROW>
                end
            end
            
            % search for station files STAT${DOY}${S}${QQ}.${YY}
            file_list = [];
            for d = 1 : numel(dir_list)
                file_name_len = numel(dir_list{d});
                if (file_name_len == 12) && ~isempty(regexp(dir_list{d}, ['.{4}[0-9]{3}.{1}[\.]{1}[0-9]{2}' file_ext '{1}'], 'once'))
                    file_list = [file_list; [dir_list{d}(1:4) '${DOY}${S}.${YY}' dir_list{d}(end)]]; %#ok<AGROW>
                    %file_list = [file_list; dir_list{d}(1:4)];
                end                    
            end
            if size(file_list, 2) > 1
                station_num = Core_Utils.code4Char2Num(file_list(:,1:4));
                station_name = unique(station_num);
                for s = 1 : numel(station_name)
                    station_list = [station_list {file_list(find(station_num == station_name(s), 1, 'first'),:)}]; %#ok<AGROW>
                end
            end
        end
    end
    
    
    methods (Static)
        function y_out = interp1LS(x_in, y_in, degree, x_out)
            % Least squares interpolant of a 1D dataset
            %
            % SYNTAX
            %   y_out = interp1LS(x_in, y_in, degree, x_out)
            
            if nargin < 4
                x_out = x_in;
            end
            
            for c = 1 : iif(min(size(y_in)) == 1, 1, size(y_in,2))
                if size(y_in, 1) == 1
                    y_tmp = y_in';
                else
                    y_tmp = y_in(:, c);
                end
                x_tmp = x_in(~isnan(y_tmp));
                y_tmp = y_tmp(~isnan(y_tmp));
                
                n_obs = numel(x_tmp);
                A = zeros(n_obs, degree + 1);
                A(:, 1) = ones(n_obs, 1);
                for d = 1 : degree
                    A(:, d + 1) = x_tmp .^ d;
                end
                
                if (nargin < 4) && numel(x_out) == numel(x_tmp)
                    A2 = A;
                else
                    n_out = numel(x_out);
                    A2 = zeros(n_out, degree + 1);
                    A2(:, 1) = ones(n_out, 1);
                    for d = 1 : degree
                        A2(:, d + 1) = x_out .^ d;
                    end
                end
                
                warning('off')
                if min(size(y_in)) == 1
                    y_out = A2 * ((A' * A) \ (A' * y_tmp(:)));
                    y_out = reshape(y_out, size(x_out, 1), size(x_out, 2));
                else
                    y_out(:,c) = A2 * ((A' * A + eye(size(A,2))) \ (A' * y_tmp(:)));
                end
                warning('on')                
            end
        end
        
        function val = linInterpLatLonTime(data, first_lat, dlat, first_lon, dlon, first_t, dt, lat, lon,t)
            % Interpolate values froma data on a gepgraphical grid with multiple epoch
            % data structure: 
            %        first dimension : dlat (+) south pole -> north pole
            %        second dimension : dlon (+) west -> east
            %        third dimension : dr (+) time usual direction
            %        NOTE: dlat, dlon,dt do not have to be positive
            % 
            % INPUT:
            %      data - the data to be interpolate
            %      fist_lat - value of first lat value (max lat)
            %      dlat - px size lat
            %      first_lon - value of first lon value
            %      dlon - px size lon
            %      first_t - value of first time
            %      dt - px size time
            %      lat - lat at what we want to interpolate
            %      lon - lon at what we ant to interpolate
            %      gps_time - time at what we want to interpolate
            % NOTES 1 - all lat values should have same unit of measure
            %       2 - all lon values should have same unit of measure
            %       3 - all time values should have same unit of measure
            %       4 - the method will interpolate first in the dimesnion with less time
            % IMPORTANT : no double values at the borders should coexist: e.g. -180 180 or 0 360
            [nlat , nlon, nt] = size(data);
            
            n_in_lat = length(lat);
            n_in_lon = length(lon);
            n_in_t = length(t);
            assert(n_in_lat == n_in_lon);
            lon(lon < first_lon) = lon(lon < first_lon) + nlon * dlon; %% to account for earth circularity 
            % find indexes and interpolating length
            % time
            it = max(min(floor((t - first_t)/ dt)+1,nt-1),1);
            st = max(min(t - first_t - (it-1)*dt, dt), 0) / dt;
            st = serialize(st);
            
            % lat
            ilat = max(min(floor((lat - first_lat)/ dlat)+1,nlat-1),1);
            slat = min(max(lat - first_lat - (ilat-1)*dlat, dlat), 0) / dlat;
            
            % lon
            ilons = max(min(floor((lon - first_lon)/ dlon)+1,nlon),1);
            ilone = ilons +1;
            ilone(ilone > nlon) = 1;
            slon = max(min(lon - first_lon- (ilons-1)*dlon, dlon), 0) / dlon;
            if n_in_lat > n_in_t % time first
                
                it = it*ones(size(ilat));
                % interpolate along time
                % [ 1 2  <= index of the cell at the smae time
                %   3 4]
                idx1 = sub2ind([nlat nlon nt], ilat, ilons, it);
                idx2 = sub2ind([nlat nlon nt], ilat, ilons, it+1);
                vallu = data(idx1).*(1-st) + data(idx2).*st;
                idx1 = sub2ind([nlat nlon nt], ilat   , ilone , it);
                idx2 = sub2ind([nlat nlon nt],ilat   , ilone , it+1);
                valru = data(idx1).*(1-st) + data(idx2).*st;
                idx1 = sub2ind([nlat nlon nt],ilat+1 , ilons , it);
                idx2 = sub2ind([nlat nlon nt],ilat+1 , ilons , it+1);
                valld =  data(idx1).*(1-st) + data(idx2).*st;
                idx1 = sub2ind([nlat nlon nt],ilat+1 , ilone , it);
                idx2 = sub2ind([nlat nlon nt],ilat+1 , ilone , it+1);
                valrd =  data(idx1).*(1-st) + data(idx2).*st;
                
                %interpolate along long
                valu = vallu.*(1-slon) + valru.*slon;
                vald = valld.*(1-slon) + valrd.*slon;
                
                %interpolate along lat
                val = valu.*(1-slat) + vald.*slat;
                
            else %space first % NOTE: consider speed up in case only one time is present, unnecessary operations done
                % interpolate along lon
                valbu = permute(data(ilat   , ilons , it  ).*(1-slon) + data(ilat   , ilone , it  ).*slon,[3 1 2]);
                valau = permute(data(ilat   , ilons , min(it+1,size(data,3))).*(1-slon) + data(ilat   , ilone , min(it+1,size(data,3))).*slon,[3 1 2]);
                valbd = permute(data(ilat+1 , ilons , it  ).*(1-slon) + data(ilat+1 , ilone , it  ).*slon,[3 1 2]);
                valad = permute(data(ilat+1 , ilons , min(it+1,size(data,3))).*(1-slon) + data(ilat+1 , ilone , min(it+1,size(data,3))).*slon,[3 1 2]);
                
                %interpolate along lat
                valb = valbd.*(1-slat) + valbu.*slat;
                vala = valad.*(1-slat) + valau.*slat;
                
                %interpolate along time
                val = valb.*(1-st) + vala.*st;
            end
            
        end
        
        function createEmptyProject(base_dir, prj_name)
            % create empty config file
            %
            % SYNTAX
            %    createEmptyProject(base_dir, prj_name)
            %    createEmptyProject(prj_name)
            
            fnp = File_Name_Processor();
            state = Main_Settings();

            if nargin == 1
                prj_name = base_dir;
                base_dir = fnp.getFullDirPath([state.getHomeDir filesep '..']);
            end
            
            log = Logger.getInstance();
            log.addMarkedMessage(sprintf('Creating a new project "%s" into %s', prj_name, [base_dir filesep prj_name]));
            
            [status, msg, msgID] = mkdir(fnp.checkPath([base_dir filesep prj_name]));
            [status, msg, msgID] = mkdir(fnp.checkPath([base_dir filesep prj_name filesep 'config']));
            [status, msg, msgID] = mkdir(fnp.checkPath([base_dir filesep prj_name filesep 'out']));
            [status, msg, msgID] = mkdir(fnp.checkPath([base_dir filesep prj_name filesep 'RINEX']));
            [status, msg, msgID] = mkdir(fnp.checkPath([base_dir filesep prj_name filesep 'station']));
            [status, msg, msgID] = mkdir(fnp.checkPath([base_dir filesep prj_name filesep 'station/CRD']));
            [status, msg, msgID] = mkdir(fnp.checkPath([base_dir filesep prj_name filesep 'station/MET']));
            state.setPrjHome(fnp.checkPath([base_dir filesep prj_name]));
            state.prj_name = prj_name;
            config_path = fnp.checkPath([base_dir filesep prj_name filesep 'config' filesep 'config.ini']);
            state.save(config_path);
        end
    end
end
