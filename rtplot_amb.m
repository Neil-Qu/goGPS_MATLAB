function rtplot_amb (t, delta, stima_amb, sigma_amb, cs, fig)

% SYNTAX:
%   rtplot_amb (t, pos_R, check_on, check_off, check_pivot, check_cs, nomefile);
%
% INPUT:
%   t = survey time (t=1,2,...)
%   pos_R = ROVER assessed position (X,Y,Z)
%   check_on = boolean variable for satellite birth
%   check_off = boolean variable for satellite death
%   check_pivot = boolean variable for change of pivot
%   check_cs = boolean variable for cycle-slip
%   fig = figure number
%   nomefile = name of file with path recall
%
% DESCRIPTION:
%   Real-time plot of the assessed ROVER path with respect to 
%   a reference path.

%----------------------------------------------------------------------------------------------
%                           goGPS v0.1 pre-alpha
%
% Copyright (C) 2009 Mirko Reguzzoni*, Eugenio Realini**
%
% * Laboratorio di Geomatica, Polo Regionale di Como, Politecnico di Milano, Italy
% ** Media Center, Osaka City University, Japan
%----------------------------------------------------------------------------------------------
%
%    This program is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.
%----------------------------------------------------------------------------------------------

figure(fig)

if (t == 1)

   sat = find(stima_amb ~= 0);                  % satellites in view (not pivot)
   nsat = length(sat);                          % number of satellites in view

   dt = (1 : delta)';

   for i = 1 : nsat
      subfig(i) = subplot(round(nsat/2),2,i);

      %assessed N combination
      plot(t, stima_amb(sat(i)), 'b.-');
      hold on; grid on;

      %acceptability range
      plot(t, stima_amb(sat(i)) + sigma_amb(sat(i)),'r:');
      plot(t, stima_amb(sat(i)) - sigma_amb(sat(i)),'r:');
      hold off

      %satellite id
      set(subfig(i),'UserData',sat(i));

      %axes and title
      ax = axis;
      axis([dt(1) dt(delta) floor(ax(3)) ceil(ax(4))]);
      title(['SATELLITE ',num2str(sat(i))]);
   end

else

   b1 = zeros(32,delta);
   b2 = zeros(32,delta);
   b3 = zeros(32,delta);

   subfig = get(fig,'Children');
   tLim = get(subfig(1),'XLim');
   dt = (tLim(1) : tLim(2))'; 

   for i = 1 : length(subfig)
      sat = get(subfig(i),'UserData');
      subobj = get(subfig(i),'Children');

      tData = get(subobj(end),'XData')';
      b1(sat,tData-dt(1)+1) = get(subobj(end),'YData');
      b2(sat,tData-dt(1)+1) = get(subobj(end-1),'YData') - b1(sat,tData-dt(1)+1);

      if (length(subobj) > 3)
         tData = get(subobj(1),'XData')';
         b3(sat,tData-dt(1)+1) = get(subobj(1),'YData');
      end
   end

   if (t <= delta)
      b1(:,t) = stima_amb;
      b2(:,t) = sigma_amb;
      b3(:,t) = stima_amb .* cs;
      dt = (1 : delta)';
   else
      b1(:,1:end-1) = b1(:,2:end);
      b2(:,1:end-1) = b2(:,2:end);
      b3(:,1:end-1) = b3(:,2:end);
      b1(:,end) = stima_amb;
      b2(:,end) = sigma_amb;
      b3(:,end) = stima_amb .* cs;
      dt = (t-delta+1 : t)';
   end

   %----------------------------------------------------------------------------

   clf                                          % delete previous sub-figures

   sat = find(sum(b1,2) ~= 0);					% satellites in view (not pivot)
   nsat = length(sat);                          % number of satellites in view

   for i = 1 : nsat

      subfig(i) = subplot(round(nsat/2),2,i);

      j = find(b1(sat(i),:) ~= 0);
      k = find(b3(sat(i),:) ~= 0);

      %assessed N combination
      plot(dt(j), b1(sat(i),j), 'b.-');
      hold on; grid on;

      %acceptability range
      plot(dt(j), b1(sat(i),j) + b2(sat(i),j),'r:');
      plot(dt(j), b1(sat(i),j) - b2(sat(i),j),'r:');

      %cycle-slips
      plot(dt(k), b3(sat(i),k),'g.');
      hold off

      %satellite id
      set(subfig(i),'UserData',sat(i));

      %axes and title
      ax = axis;
      axis([dt(1) dt(delta) floor(ax(3)) ceil(ax(4))]);
      title(['SATELLITE ',num2str(sat(i))]);
   end
end

%-------------------------------------------------------------------------------