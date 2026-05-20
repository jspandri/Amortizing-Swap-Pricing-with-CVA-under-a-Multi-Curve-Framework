function [euriborSet, estrSet] = read_Excel_data(filename, settlement)


sheets = sheetnames(filename);

euribor_data = readtable(filename, 'Sheet', sheets(1), 'Range', 'A:B', ...
                    'VariableNamingRule','preserve');
euriborSet = euribor_instruments_classifier(euribor_data, settlement);

estr_data = readtable(filename, 'Sheet', sheets(2), 'Range', 'A:B', ...
                    'VariableNamingRule','preserve');
estrSet = estr_instruments_classifier(estr_data, settlement);

end