% script to inverse the 3D shear velocity structure of PNG, using ambient noise and earthquake rayleigh wave inversion
% using same 1D initial model
% adding water depth variation
%
% written by Ge Jin, jinwar@gmail.com

clear
tic
load tomo.mat
load png_topo.mat

[xi yi] = ndgrid(xnode,ynode);
topo = interp2(grdxi,grdyi,grdtopo,xi,yi);

initmod.crusth = 30;
initmod.crustv = 3.7;
initmod.mantlev = 4.3;
initmod.sedh = 5;
initmod.sedv = 2.5;
vpvs = 1.8;

% make starting model
depth = [0:2:10, 12:2:50, 55:5:100, 110:20:150];
vec_h = diff(depth);
vec_z = depth(2:end);
vec_vs = initmod.crustv*ones(size(vec_h));
mantleind = find(depth > initmod.crusth)-1;
vec_vs(mantleind) = initmod.mantlev;
sedind = find(depth < initmod.sedh);
vec_vs(sedind) = initmod.sedv;
vec_vp=vec_vs*vpvs;
vec_rho=2.7*ones(size(vec_h));
vec_rho(mantleind)=3.3;

initmod.model(:,1) = vec_h(:);
initmod.model(:,2) = vec_vp(:);
initmod.model(:,3) = vec_vs(:);
initmod.model(:,4) = vec_rho(:);

[Nlat Nlon] = size(tomo(1).phV);
Ndepth = size(initmod.model,1);
shearV3D = zeros(Ndepth,Nlat,Nlon);
initV3D = zeros(Ndepth,Nlat,Nlon);
regmap = zeros(Nlat,Nlon);
errmat = zeros(Nlat,Nlon);
periods = [tomo.period];
phV3D = zeros(length(periods),Nlat,Nlon);

make_par_surf96('R');

for ilat = 1:Nlat
	for ilon = 1:Nlon
		disp(['ilat:',num2str(ilat),' ilon:',num2str(ilon)]);
		clear phv velT
		velT = periods;
		for ip = 1:length(periods)
			phv(ip) = tomo(ip).phV(ilat,ilon);
		end
		badind = find(isnan(phv));
		phv(badind) = [];
		velT(badind) = [];
		if length(phv) < 10
			continue;
		end
		initmod.model(:,3) = nanmean(phv);
		initmod.model(:,2) = vpvs*nanmean(phv);
		phvstd = 0.05*ones(size(phv));
		grv = [];
		grvstd = [];
		initmodel = initmod.model;
		if topo(ilat,ilon) < 0
			waterdepth = -topo(ilat,ilon)/1e3;
			initmodel = [waterdepth 1.5 0 1;initmodel];
		else
			waterdepth = 0;
		end
		h_crust=-1;
		[outmod phv_fwd] = invdispR(velT,phv,phvstd,grv,grvstd,initmodel,h_crust,waterdepth,10)
		misfit = (phv_fwd(:)-phv(:));
		rms=sqrt(sum(misfit.^2)/length(velT))
		if waterdepth > 0
			shearV3D(:,ilat,ilon) = outmod(2:end,3);
			initV3D(:,ilat,ilon) = initmodel(2:end,3);
%			pause
		else
			shearV3D(:,ilat,ilon) = outmod(:,3);
			initV3D(:,ilat,ilon) = initmodel(:,3);
		end
		if length(phv_fwd) == length(periods)
			phV3D(:,ilat,ilon) = phv_fwd(:);
		else
			for ip = 1:length(velT)
				phV3D(find(velT(ip) == periods),ilat,ilon) = phv_fwd(ip);
			end
		end
		errmat(ilat,ilon) = rms;
		regmat(ilat,ilon) = 1;
	end
end

[xi yi] = ndgrid(xnode,ynode);
lalim = [min(xnode) max(xnode)];
lolim = [min(ynode) max(ynode)];
depth_prof = vec_z;

save 3Dinv_result shearV3D errmat xnode ynode depth_prof regmap phV3D vec_h initV3D

figure(48)
clf
ax = worldmap(lalim, lolim);
set(ax, 'Visible', 'off')
h1=surfacem(xi,yi,errmat);
drawpng
toc
