clc;clear;
warning off;

res = load("result.txt");

mu = zeros(1201,1);
sigma = zeros(1201,1);
mu(1) = 0;
sigma(1) = 1e-4;
for i = 2:1201
    mu(i) = mean(res(i,:)/max(res(i,:)));
    sigma(i) = std(res(i,:)/max(res(i,:)));
end

xdata = linspace(0.99,1.01,2000);
ydata = zeros(1201,2000);

for i = 1 : 1201
    pd = makedist('Normal','mu',mu(i,1),'sigma',sigma(i,1));
%     ydata(i,:) = calculatingnormaldata(pd,xdata);
    for j = 1:2000
        ydata(i,j) = pdf(pd,xdata(1,j));
    end
end

ydata;
% function calculatingnormaldata(pd,x)
%     y = zeros(size(x,1),1);
%     for i =1:size(x,1)
%         y(i,1) = pdf(pd,x(i,1));
%     end
%     return y
% end