function [euriborSet, estrSet] = read_bootstrap_data(filename, settlement)
% READ_BOOTSTRAP_DATA Read Excel data of Euribor3m and OIS ESTR instruments (1st and 2nd sheets) and computes corresponding dates.
% Returns euriborSet and estrSet containing ordered and classified instruments dates and rates.
%
% INPUTS:
%   filename           : [String/Char] name of Excel file.
%   settlement         : [Scalar/Datetime] settlement date.
%
% OUTPUTS:
%   euriborSet         : [Struct] Euribor3m set of classified and ordered dates and
%                                 rates.
%   estrSet            : [Struct] OIS ESTR set of ordered dates and rates.

% Extract sheets names
sheets = sheetnames(filename);

% Read Euribor3m data as table
euribor_data = readtable(filename, 'Sheet', sheets(1), 'Range', 'A:B', ...
                    'VariableNamingRule','preserve');
% Classify and order instruments into a Set
euriborSet = euribor_instruments_classifier(euribor_data, settlement);

% Read OIS ESTR data as table
estr_data = readtable(filename, 'Sheet', sheets(2), 'Range', 'A:B', ...
                    'VariableNamingRule','preserve');
% Order instruments into a set
estrSet = estr_instruments_classifier(estr_data, settlement);

end