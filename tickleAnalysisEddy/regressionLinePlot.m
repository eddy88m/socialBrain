function [R,P,Rsquare] = regressionLinePlot(xValues,yValues,varargin)
if ~isempty(varargin)
    maxValue = cell2mat(varargin);
else
    maxValue = input('maximal Value?');
    maxValue_x = input('maximal Value for x?');
    maxValue_y = input('maximal Value for y?');
end
[R,P] = corrcoef(xValues,yValues)
Rsquare = R(1,2)^2;
slope = R(1,2)*(std(yValues)/std(xValues));
y = mean(yValues)-(mean(xValues)*slope);
x = 0:maxValue/10:maxValue;

plot(xValues,yValues,'.','MarkerSize',20,'Color',[0 0 0])
hold on
plot(x,slope*x+y,'k-')%regression line
hold on
plot(0:maxValue/10:maxValue,0:maxValue/10:maxValue,'Color', [0.5 0.5 0.5])
xlim([- maxValue_x maxValue_x])
ylim([-maxValue_y maxValue_y])