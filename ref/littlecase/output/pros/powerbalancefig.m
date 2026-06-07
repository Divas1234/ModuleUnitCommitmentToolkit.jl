<<<<<<< HEAD
data(:,1) = load("res_thermalunits.txt");
data(:,2) = load("res_windunits.txt");
data(:,3) = load("res_forcedloadcurtailment.txt");
data(:,4) = load("res_BESS_discharging.txt");
data(:,5) = -load("res_BESS_charging.txt");
createfigure(data);
% 
% fig1 = area(data(:,1:4),'DisplayName','data(:,1:4)');
% % fig1 = bar(data(:,1:4),'stacked','DisplayName','data(:,1:4)');
% hold on;
% fig1 = area(data(:,5));
=======
data(:,1) = load("res_thermalunits.txt");
data(:,2) = load("res_windunits.txt");
data(:,3) = load("res_forcedloadcurtailment.txt");
data(:,4) = load("res_BESS_discharging.txt");
data(:,5) = -load("res_BESS_charging.txt");
createfigure(data);
% 
% fig1 = area(data(:,1:4),'DisplayName','data(:,1:4)');
% % fig1 = bar(data(:,1:4),'stacked','DisplayName','data(:,1:4)');
% hold on;
% fig1 = area(data(:,5));
>>>>>>> ddcc61bc698d78ffb72094c36be7666ca18eab1f
% % fig1 = bar(data(:,5));