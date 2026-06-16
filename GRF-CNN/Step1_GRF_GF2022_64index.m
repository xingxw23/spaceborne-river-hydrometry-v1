clear all
clc
% 算法供需进行两次RF模型训练，第一次筛选水体、纹理指数，第二次为训练筛选后的指数形成最终模型。
% 第一次训练使用第 1 2 3 4 5 6 7 8.1 节
% 尝试改变measurement的值 测试本计算机RAM能支持的最大数组数，如果超过RAM限制，load函数将不可用
% measurement = 7e9;                 %7e9可行,1e10不行
% rand(1, measurement);
%% 1.配置变量环境
 setenv('MW_MINGW64_LOC','C:\MinGW64')
 mex -setup                                 % 选取MinGW64 Compiler(C++)
%% 2.灰度共生矩阵计算---------------------计算210区域----------------------------
% 2.1. 导入数据，Landsat等30m及以上的卫星不需要使用纹理特征
clc
[TD_GF,corGF]=geotiffread('ex_area.tif');   % TD=testdata ，路径为导入数据路径，格式为tiff
info=geotiffinfo('ex_area.tif');            % 路径为导入数据路径，格式为tiff
band1=TD_GF(:,:,1);           % GF影像 1-4波段二维 
band2=TD_GF(:,:,2);
band3=TD_GF(:,:,3);
band4=TD_GF(:,:,4);
clear TD_GF                   % 删去无用数据
band1=single(band1);          % single是为了节省空间
band2=single(band2);
band3=single(band3);
band4=single(band4);
[q1,t1]=size(band1);
%% 3.1 EVI部分奇点指数
% EVI的处理和归一化
EVI = zeros(q1,t1,'single');
EVI = 2.5*(band4-band3)./((band4+6*band3-7.5*band1)+1);
EVI(EVI==inf)=nan;                    %将inf/-inf 这类超限值替换成nan,否则无法归一化
EVI(EVI==-inf)=nan;
% evi 去掉NAN且归一化至0~1区间 而且mapminmax 是按行归一化的
[m1,n1]=size(EVI);
evi1=reshape(EVI,1,[]);
max_evi1=max(evi1);
min_evi1=min(evi1);
[evi11,~] = mapminmax(evi1,0,1);       % 归一化到0-1之间，并把NAN变成0        
evin=reshape(evi11,m1,n1);
evin(isnan(evin))=0;  
I2=evin;                               % 其对于山体阴影的判断较好
clear evi1 evi11 evin                  % 后续水体指数仅需要EVI
% 将I2每个分成16份，用reshape函数最后反演好了再用reshape复原
z=4;           % 元胞分块数z，可调。本算例为z=4,即 4x4,若改为z=6 则配套的97行开始也要改 
mm=fix(q1/z);  % fix函数是向0取整，如1.9取为1，这样能与余数函数配套
mm1=rem(q1,z);
nn=fix(t1/z);
nn1=rem(t1,z);
I21 = mat2cell(I2,[mm mm mm mm+mm1],[nn nn nn nn+nn1]);
clear I2
% 将evi分块并整合，供并行运算使用
kk=1;          % 计数器kk
for i = 1:z-1
   for j = 1:z-1
    i21(:,:,kk)=I21{i,j};
    kk=kk+1;
   end
end
kk=1;
for i= 1:z-1
    i22(:,:,kk)=I21{i,z};
    kk=kk+1;
end
kk=1;
for j= 1:z-1
    i23(:,:,kk)=I21{z,j};
    kk=kk+1;
end
i24 = I21{z,z};
%% 计算evi部分
% 并行化启动,这里断开是为了提高速度
corenum=3;                                  % 调用2核运算，测试可行
if isempty(gcp('nocreate'))                  % 未开启并行化
    parpool('local',corenum);      
else disp('matlab pool already started');
end
%% 3.1.1 分元胞计算第一部分
i21=double(i21);            % Rivamap只能使用double格式
[~,~,kk]=size(i21);
parfor i =1:kk
    [orii21(:,:,i),scaleMap(:,:,i),posi21(:,:,i),centerline(:,:,i)] = ModifiedSingularityIndex2D(i21(:,:,i), 12, 1.5);    % scalemap是河宽,要用到的是orientation,多尺度奇点指数
    CenLnumI2(:,i)=length(find(centerline(:,:,i)~=0)); % CenL 检验中心线是否提取成功,不能删去
end
clear scaleMap  centerline
%% 3.1.2 分元胞计算第二部分
i22=double(i22);            % Rivamap只能使用double格式
[~,~,kk]=size(i22);
parfor i =1:kk
    [orii22(:,:,i),scaleMap(:,:,i),posi22(:,:,i),centerline(:,:,i)] =  ModifiedSingularityIndex2D(i22(:,:,i), 12, 1.5);    % scalemap是河宽,要用到的是orientation,多尺度奇点指数
    CenLnumII2(:,i)=length(find(centerline(:,:,i)~=0)); % CenL 检验中心线是否提取成功,不能删去
end
clear scaleMap  centerline
%% 3.1.3 分元胞计算第三部分
i23=double(i23);            % Rivamap只能使用double格式
[~,~,kk]=size(i23);
parfor i =1:kk
    [orii23(:,:,i),scaleMap(:,:,i),posi23(:,:,i),centerline(:,:,i)] =  ModifiedSingularityIndex2D(i23(:,:,i), 12, 1.5);    % scalemap是河宽,要用到的是orientation,多尺度奇点指数
    CenLnumIII2(:,i)=length(find(centerline(:,:,i)~=0)); % CenL 检验中心线是否提取成功,不能删去
end
clear scaleMap  centerline
%% 3.1.4 第4元胞永远是单块矩阵，不需要并行计算
i24=double(i24);
[orii24,scaleMap,posi24,centerline] =  ModifiedSingularityIndex2D(i24, 12, 1.5);
CenLnumIV2=length(find(centerline~=0));
clear scaleMap centerline
% 将ndwi计算结果还原维度,按元胞赋值
multievi = cell(4,4);
pospsievi = cell(4,4);
%
multievi{1,1}=orii21(:,:,1);
multievi{1,2}=orii21(:,:,2);
multievi{1,3}=orii21(:,:,3);
multievi{1,4}=orii22(:,:,1);
multievi{2,1}=orii21(:,:,4);
multievi{2,2}=orii21(:,:,5);
multievi{2,3}=orii21(:,:,6);
multievi{2,4}=orii22(:,:,2);
multievi{3,1}=orii21(:,:,7);
multievi{3,2}=orii21(:,:,8);
multievi{3,3}=orii21(:,:,9);
multievi{3,4}=orii22(:,:,3);
multievi{4,1}=orii23(:,:,1);
multievi{4,2}=orii23(:,:,2);
multievi{4,3}=orii23(:,:,3);
multievi{4,4}=orii24;
%
pospsievi{1,1}=posi21(:,:,1);
pospsievi{1,2}=posi21(:,:,2);
pospsievi{1,3}=posi21(:,:,3);
pospsievi{1,4}=posi22(:,:,1);
pospsievi{2,1}=posi21(:,:,4);
pospsievi{2,2}=posi21(:,:,5);
pospsievi{2,3}=posi21(:,:,6);
pospsievi{2,4}=posi22(:,:,2);
pospsievi{3,1}=posi21(:,:,7);
pospsievi{3,2}=posi21(:,:,8);
pospsievi{3,3}=posi21(:,:,9);
pospsievi{3,4}=posi22(:,:,3);
pospsievi{4,1}=posi23(:,:,1);
pospsievi{4,2}=posi23(:,:,2);
pospsievi{4,3}=posi23(:,:,3);
pospsievi{4,4}=posi24;
clear orii21 orii22 orii23 orii24 posi21 posi22 posi23 posi24
orievi = cell2mat(multievi);
posevi = cell2mat(pospsievi);
clear multievi pospsievi        % 清理无用内存
orievi=single(orievi);          % 转换格式，节省内存
posevi=single(posevi);
CenterlineNUM=CenLnumIV2+sum(CenLnumI2)+sum(CenLnumII2)+sum(CenLnumIII2);                 % RivaMap中心线求和，检验算法是否成功，即CNUM不等于0
clear I11 I21 i11 i12 i13 i14 i21 i22 i23 i24 CenLnumI2 CenLnumII2 CenLnumIII2 CenLnumIV2 % 清理内存，去掉不用的数据
timetik= '多尺度奇点指数计算完毕';
disp(timetik);
%% 4.1 （模型训练前） HFC使用的水体指数
NDWI = zeros(q1,t1,'single'); 
NDVI = zeros(q1,t1,'single');
GDVI = zeros(q1,t1,'single');
WDVI = zeros(q1,t1,'single');
SRRed_NIR = zeros(q1,t1,'single');
Fe3 = zeros(q1,t1,'single');                       
CRI550 = zeros(q1,t1,'single');                    
NCWI = zeros(q1,t1,'single');
PBNDVI = zeros(q1,t1,'single');
D678 = zeros(q1,t1,'single');
SWI = zeros(q1,t1,'single');
ESWI = zeros(q1,t1,'single');
NCWI = zeros(q1,t1,'single');
GNDVI = zeros(q1,t1,'single');
RVI = zeros(q1,t1,'single');
DVI = zeros(q1,t1,'single');
RDVI = zeros(q1,t1,'single');
PNDVI = zeros(q1,t1,'single');
PBNDVI = zeros(q1,t1,'single');
BNDVI = zeros(q1,t1,'single');
BWDRVI = zeros(q1,t1,'single');
ATSAVI = zeros(q1,t1,'single');
TSAVI = zeros(q1,t1,'single');
IF = zeros(q1,t1,'single');
CI = zeros(q1,t1,'single');
VARIgreen = zeros(q1,t1,'single');
IO = zeros(q1,t1,'single');
RI = zeros(q1,t1,'single');
SR520 = zeros(q1,t1,'single');
SR550 = zeros(q1,t1,'single');
SR800 = zeros(q1,t1,'single');
D678 = zeros(q1,t1,'single');
%
NDWI = (band2-band4)./(band2+band4);
SWI = band1+band2-band4;
ESWI = (band1+band2)./(band4+band4);
NCWI = (7*band2-2*band1-5*band4)./(7*band2+2*band1+5*band4);
NDVI = (band4-band3)./(band4+band3);
GNDVI = (band4-band2)./(band4+band2);
RVI = band4./band3;
DVI = band4-band3 ;
GDVI = band4-band2;
WDVI = band4-0.46*band3;
RDVI =(band4-band3)./(band4+band3).^0.5;
PNDVI =(band4-(band2+band3+band1))./(band4+(band2+band3+band1));
PBNDVI = (band4-(band3+band1))./(band4+(band3+band1));
BNDVI = (band4-band1)./(band4+band1);
BWDRVI = (0.1*band4-band1)./(0.1*band4+band1);
SRRed_NIR = band3./band4;
ATSAVI = 1.22*(band4-1.22*band3-0.03)./(1.22*band4+band3-1.22*0.03+0.08*(1.0+1.22.^2));
TSAVI = (0.743*(band4-0.743*band3-0.323))./(band3+0.743*(band4-0.323)+0.413*(1+0.743.^2));
Fe3 = band3./band2;
IF = (2*band3-band2-band1)./(band2-band1);
CI = (band3-band1)./band3;
VARIgreen = (band2-band3)./(band2+band3-band1);
IO = band3./band1;
RI = (band3-band2)./(band3+band2);
CRI550 = band1.^(-1)-band2.^(-1);
SR520 = band1./band3;
SR550 = band2./band4;
SR800 = band4./band2;
D678 = band3-band1;
%
timetik='4.1 水体指数挑选并计算完毕';
disp(timetik);
%% 5. 通过envi计算的GLCM 4波段数据
[GF_GLCMb1,~]=geotiffread('E:\XUE&XING\cutofpic\GLCM\band1.tif'); % 分别导入4个波段的灰度共生矩阵，分开导入提升导入效率
[GF_GLCMb2,~]=geotiffread('E:\XUE&XING\cutofpic\GLCM\band2.tif');  % 在R22区域，B2,B3的灰度共生矩阵即可
[GF_GLCMb3,~]=geotiffread('E:\XUE&XING\cutofpic\GLCM\band3.tif');
[GF_GLCMb4,~]=geotiffread('E:\XUE&XING\cutofpic\GLCM\band4.tif');
timetik= '水体指数及纹理指数载入程序';
disp(timetik);
%% 6.训练样本标签确定，需在输入前检验是否含有重复项
% 河流样本标记为1
[Label1]=xlsread('E:\XUE&XING\cutofpic\R&C\all.xlsx',1);
A=Label1(:,1);                             %水体样本在影像中的行数
B=Label1(:,2);                             %水体样本在影像中的列数
Label_tr1=zeros(q1,t1,'double');
Label_tr1(sub2ind(size(Label_tr1),A,B))=1; %将样本点在0矩阵中赋值为1
% 农田样本标记为2
[Label2]=xlsread('E:\XUE&XING\cutofpic\R&C\all.xlsx',2);
A=Label2(:,1);                             %农田样本在影像中的行数
B=Label2(:,2);                             %农田样本在影像中的列数
Label_tr1(sub2ind(size(Label_tr1),A,B))=2; %将样本点在0矩阵中赋值为2
% 建筑物样本标记为3
 [Label3]=xlsread('E:\XUE&XING\cutofpic\R&C\all.xlsx',3);
A=Label3(:,1);                             %城市样本在影像中的行数
B=Label3(:,2);                             %城市样本在影像中的列数
Label_tr1(sub2ind(size(Label_tr1),A,B))=3; %将样本点在0矩阵中赋值为3
% 山体阴影样本标记为4
[Label4]=xlsread('E:\XUE&XING\cutofpic\R&C\all.xlsx',4);
A=Label4(:,1);                             %山体样本在影像中的行数
B=Label4(:,2);                             %山体样本在影像中的列数
Label_tr1(sub2ind(size(Label_tr1),A,B))=4; %将样本点在0矩阵中赋值为4
% 裸土样本标记为5
[Label5]=xlsread('E:\XUE&XING\cutofpic\R&C\all.xlsx',5);
A=Label5(:,1);                             %裸土样本在影像中的行数
B=Label5(:,2);                             %裸土样本在影像中的列数
Label_tr1(sub2ind(size(Label_tr1),A,B))=5; %将样本点在0矩阵中赋值为5
gt=reshape(Label_tr1,[],1);                %二维矩阵转一维,是所有样本行号的统计矩阵
[~,~,class]=find(unique(gt));              %返回gt中的不重复值的位置
Label1 = uint16(Label1);
Label2 = uint16(Label2);
Label3 = uint16(Label3);
Label4 = uint16(Label4);
Label5 = uint16(Label5);
Label_tr1 = uint16(Label_tr1);
gt = uint16(gt);
% 用以检验样本导入是否成功
Spsnum_1=length(find((Label_tr1)==1));
Spsnum_2=length(find((Label_tr1)==2));
Spsnum_3=length(find((Label_tr1)==3));
% Spsnum_3=0;
Spsnum_4=length(find((Label_tr1)==4));
Spsnum_5=length(find((Label_tr1)==5));
YBFB(1,:)=single(Spsnum_1)/(Spsnum_1+Spsnum_2+Spsnum_3+Spsnum_4+Spsnum_5);  % YBFB=样本分布， 最后一行为样本总数
YBFB(2,:)=single(Spsnum_2)/(Spsnum_1+Spsnum_2+Spsnum_3+Spsnum_4+Spsnum_5);
YBFB(3,:)=single(Spsnum_3)/(Spsnum_1+Spsnum_2+Spsnum_3+Spsnum_4+Spsnum_5);
YBFB(4,:)=single(Spsnum_4)/(Spsnum_1+Spsnum_2+Spsnum_3+Spsnum_4+Spsnum_5);
YBFB(5,:)=single(Spsnum_5)/(Spsnum_1+Spsnum_2+Spsnum_3+Spsnum_4+Spsnum_5);
YBFB(6,:)=Spsnum_1+Spsnum_2+Spsnum_3+Spsnum_4+Spsnum_5;

timetik= '学习样本标签预处理完毕';
disp(timetik);
%%
clear Spsnum_1 Spsnum_2 Spsnum_3 Spsnum_4 Spsnum_5
clear A B Label1 Label2 Label3 Label4 Label5
%% 7. 初次训练模型筛选指数时适用，更改格式准备开始RF学习
% 7.1 全部参数用以训练，暂时先不筛选
NDWI = reshape(NDWI,[],1);                               
NDVI = reshape(NDVI,[],1);                               
GDVI = reshape(GDVI,[],1);                               
WDVI = reshape(WDVI,[],1);                               
SRRed_NIR = reshape(SRRed_NIR,[],1);                     
Fe3 = reshape(Fe3,[],1);                                 
CRI550 = reshape(CRI550,[],1);                                                        
SR520 = reshape(SR520,[],1);
SR550 = reshape(SR550,[],1);
SR800 = reshape(SR800,[],1);
D678 = reshape(D678,[],1);
SWI = reshape(SWI,[],1);
ESWI = reshape(ESWI,[],1);
NCWI = reshape(NCWI,[],1);
GNDVI = reshape(GNDVI,[],1);
RVI = reshape(RVI,[],1);
EVI = reshape(EVI,[],1);
DVI = reshape(DVI,[],1);
RDVI = reshape(RDVI,[],1);
PNDVI = reshape(PNDVI,[],1);
PBNDVI = reshape(PBNDVI,[],1);
BNDVI = reshape(BNDVI,[],1);
BWDRVI = reshape(BWDRVI,[],1);
ATSAVI = reshape(ATSAVI,[],1);
TSAVI = reshape(TSAVI,[],1);
IF = reshape(IF,[],1);
CI = reshape(CI,[],1);
VARIgreen = reshape(VARIgreen,[],1);
IO = reshape(IO,[],1);
RI = reshape(RI,[],1);
multi_ori2=reshape(orievi,[],1);
multi_pos2=reshape(posevi,[],1);
% 不能将nodata设置成0，不然会使RF学习0这个值
GLCM_b1 = reshape(GF_GLCMb1,[],8);
GLCM_b2 = reshape(GF_GLCMb2,[],8);
GLCM_b3 = reshape(GF_GLCMb3,[],8);
GLCM_b4 = reshape(GF_GLCMb4,[],8);
GLCM_b1(GLCM_b1==0)=nan;
GLCM_b2(GLCM_b2==0)=nan;
GLCM_b3(GLCM_b3==0)=nan;
GLCM_b4(GLCM_b4==0)=nan;
% 7.1 数据源汇总，共有64个特征
datasource_t = zeros(q1*t1,64,'single');
datasource_t(:,1)= NDWI;
datasource_t(:,2)= SWI;
datasource_t(:,3)= ESWI;
datasource_t(:,4)= NCWI;
datasource_t(:,5)= NDVI;
datasource_t(:,6)= GNDVI;
datasource_t(:,7)= RVI;
datasource_t(:,8)= EVI;
datasource_t(:,9)= DVI;
datasource_t(:,10)= GDVI;
datasource_t(:,11)= WDVI;
datasource_t(:,12)= RDVI;
datasource_t(:,13)= PNDVI;
datasource_t(:,14)= PBNDVI;
datasource_t(:,15)= BNDVI;
datasource_t(:,16)= BWDRVI;
datasource_t(:,17)= SRRed_NIR;
datasource_t(:,18)= ATSAVI;
datasource_t(:,19)= TSAVI;
datasource_t(:,20)= Fe3;
datasource_t(:,21)= IF;
datasource_t(:,22)= CI;
datasource_t(:,23)= VARIgreen;
datasource_t(:,24)= IO;
datasource_t(:,25)= RI;
datasource_t(:,26)= CRI550;
datasource_t(:,27)= SR520;
datasource_t(:,28)= SR550;
datasource_t(:,29)= SR800;
datasource_t(:,30)= D678;
datasource_t(:,31:38)= GLCM_b1;
datasource_t(:,39:46)= GLCM_b2;
datasource_t(:,47:54)= GLCM_b3;
datasource_t(:,55:62)= GLCM_b4;
datasource_t(:,63)=multi_ori2;
datasource_t(:,64)=multi_pos2;
datasource_t(datasource_t==inf)=nan;              %将inf/-inf 这类超限值替换成nan
datasource_t(datasource_t==-inf)=nan; 

timetik='数据前期准备完毕';
disp(timetik);
% 保存了含有NAN信息的datasource_t（EVI被选为多尺度奇点指数所以经过了去NAN，如果最后的8参数中含有EVI则另当别论）
save('E:\XUE&XING\pretest_result\R11_alldata.mat','datasource_t');
timetik= '训练用datasource_t备份完毕';
disp(timetik);
%%
% 节省内存,去掉不用的变量
clear NDWI NDVI	GDVI WDVI SRRed_NIR	Fe3	CRI550	EVI	NCWI PBNDVI	D678 SWI ESWI NCWI GNDVI RVI EVI DVI RDVI PNDVI PBNDVI BNDVI BWDRVI	ATSAVI TSAVI IF	CI VARIgreen IO RI SR520 SR550 SR800 D678
clear GLCM_b1 GLCM_b2 GLCM_b3 GLCM_b4 GF_GLCMb1 GF_GLCMb2 GF_GLCMb3 GF_GLCMb4
clear multi_ori2  multi_pos2 band1 band2 band3 band4 orievi posevi
%% 8.0.2 分步采样,单独运行每节，速度较快
[~,yy]=size(datasource_t);
perf=0.7;                                   % 指定选取样本的比例(可以尝试10%-90%),一般选取0.5-0.7之间
train_label1=zeros(length(gt),1,'uint16');
test_label=gt; 
train_sample=zeros(length(gt),yy,'single');
test_sample=zeros(length(gt),yy,'single');
[classNum,~] = size(class);
%%
[a1,~]=size(Label1);
[a2,~]=size(Label2);
[a3,~]=size(Label3);
[a4,~]=size(Label4);
[a5,~]=size(Label5);
%%
order_a = [a1 a2 a3 a4 a5];   % 代表着每类样本的总数，与采样率乘积即为学习样本个数，由于各类样本总数均不同，所以乘积结果有所不同
% 带有下标的赋值维度不等,因此直接采用速度最快的读取方式,yc系列也是检验gt中数量的
[yc1,~,~]=find(gt==class(1));
[yc2,~,~]=find(gt==class(2));
[yc3,~,~]=find(gt==class(3));
[yc4,~,~]=find(gt==class(4));
[yc5,~,~]=find(gt==class(5));
index_1=randperm(length(yc1));     % 随机排序后的样本标签
index_2=randperm(length(yc2));
index_3=randperm(length(yc3));
index_4=randperm(length(yc4));
index_5=randperm(length(yc5));
order1= ceil(perf*order_a);        % 确定各样本个数 
% 
qybq1= index_1(1:order1(1))';      % 按照采样比例确定样本行列号
qybq2= index_2(1:order1(2))';
qybq3= index_3(1:order1(3))';
qybq4= index_4(1:order1(4))';
qybq5= index_5(1:order1(5))';
BQ1=yc1(qybq1,1); 
BQ2=yc2(qybq2,1); 
BQ3=yc3(qybq3,1); 
BQ4=yc4(qybq4,1); 
BQ5=yc5(qybq5,1);
%
% 河流水体样本1
train_label1(BQ1)=class(1); 
train_sample(BQ1,:)=datasource_t(BQ1,:);
% 农田耕地样本2
train_label1(BQ2)=class(2); 
train_sample(BQ2,:)=datasource_t(BQ2,:);
% 城市建筑样本3
train_label1(BQ3)=class(3); 
train_sample(BQ3,:)=datasource_t(BQ3,:);
% 山体阴影样本4
train_label1(BQ4)=class(4); 
train_sample(BQ4,:)=datasource_t(BQ4,:);
% 山体植被样本5
train_label1(BQ5)=class(5); 
train_sample(BQ5,:)=datasource_t(BQ5,:);
% 去掉标签中的0
[index1,~,train_label]=find(train_label1);  % [a,b,v] = find(A)，找出A中非零元素所在的行和列，分别存储在a和b中，并将结果放在v中
%[index2,~,test_label]=find(test_label);    % index2存储着测试样本的行号，可反查
% 获取测试样本的属性矩阵
% for i=1:length(index2)
%    test_sample(index2(i),:)=datasource_t(index2(i),:);
% end;
%% 去掉属性矩阵中整行都为0的,防止把所有的0都去掉   
row1 = find(all(train_sample ==0,2));        
% row2 = find(all(test_sample ==0,2));
train_sample(row1,:) = [];
% test_sample(row2,:) = [];
% 查找全为NAN的行,并在标签和数据中全部删除,针对 GLCM 数据使用
row3 = find(all(isnan(train_sample),2));   % 返回整行都是NAN的
% row4 = find(all(isnan(test_sample),2));
train_label(row3,:) = [];
train_sample(row3,:)= [];
% test_label(row4,:) = [];
% test_sample(row4,:)= [];
train_sample(isnan(train_sample))=0;    %随机森林参数中不能有NAN要将其改为其他值，本算例改为0
% test_sample(isnan(test_sample))=0;
train_sample = double(train_sample);
train_label = double(train_label);
% test_sample = double(test_sample);
row1 = single(row1);                    %改变存储类型，减少内存损耗
% row2 = single(row2);
row3 = single(row3);
% row4 = single(row4);
% 将 datasource 变成测试集进行整体分类了
row5 = find(all(isnan(datasource_t),2));         % 将整行都是NAN的行号记录下来.并且 row,gt的类型均需要是double才行
datasource_t(row5,:) = [];
datasource_t = double(datasource_t);
datasource_t(isnan(datasource_t)) = 0;             % datasource里的nan都要改为0
%
timetik= '训练样本导入成功';
disp(timetik);
%%
clear train_label1 index_1 index_2 index_3 index_4 index_5 qybq1 qybq2 qybq3 qybq4 qybq5 BQ1 BQ2 BQ3 BQ4 BQ5 a1 a2 a3 a4 a5
%% 8.1 RF函数训练测试，可先进行预实验测试随机森林预设参数 51.5万 x 12 列（本例70%） 的训练样本可以正常运行
model = classRF_train(train_sample,train_label,1100,8,'importance localImp');
timetik= 'RF模型训练完毕';
disp(timetik);
%% 8.2-1 （训练后) 更改格式准备开始RF学习，8个参数
% 21区域选定参数为 水体指数：
%                 纹理指数：
clear all
datasourceBF =load('J:\2022HFC_dry\GF_R24\R24_datasource'); % 节省每次的运算时间
datasource_c = datasourceBF.datasource;
%
datasource(:,1)=datasource_c(:,20); %从备份中读取 Fe3
datasource(:,2)=datasource_c(:,23); %从备份中读取 VARIg
datasource(:,3)=datasource_c(:,24); %从备份中读取 IO
datasource(:,4)=datasource_c(:,12); %从备份中读取 RDVI
datasource(:,5)=datasource_c(:,63); %从备份中读取 OriEVI
datasource(:,6)=datasource_c(:,64); %从备份中读取 PosEVI
datasource(:,7)=datasource_c(:,47); %从备份中读取 GLCMB3_对比度
datasource(:,8)=datasource_c(:,55); %从备份中读取 GLCMB4_对比度
%
clear datasourceBF datasource_c
timetik= '正式训练模型指数选取及导入完成';
disp(timetik);
save('H:\RemotesensingImagery\HFC_Dryseason\riversourceregion\Region2_4\R24_Classdata.mat','datasource');
timetik= '正式datasource备份完毕';
disp(timetik);
%% 8.3 按照指定比例随机选取样本,尽可能断点操作，一次性跑完本节很慢(对于R22其他区域不需要重新训练直接用RFmodel就行)
 [TD_GF,corGF]=geotiffread('J:\2022HFC_dry\GF_R24\GF_re2_4.tif');   % TD=testdata ，路径为导入数据路径，格式为tiff
 info=geotiffinfo('J:\2022HFC_dry\GF_R24\GF_re2_4.tif');            % 路径为导入数据路径，格式为tiff
 band1=TD_GF(:,:,1);           % GF影像 1-4波段二维 
 [q1,t1]=size(band1);
 clear TD_GF band1             % 删去无用数据 保留info和corGF
% 训练样本标签确定，需在输入前检验是否含有重复项，2_2区域去掉城市分类
% 河流样本标记为1
[Label1]=xlsread('J:\2022HFC_dry\GF_R24\r24_trainsamples.xlsx',1);
A=Label1(:,1);                             %水体样本在影像中的行数
B=Label1(:,2);                             %水体样本在影像中的列数
Label_tr1=zeros(q1,t1,'double');
Label_tr1(sub2ind(size(Label_tr1),A,B))=1; %将样本点在0矩阵中赋值为1
% 农田样本标记为2
[Label2]=xlsread('J:\2022HFC_dry\GF_R24\r24_trainsamples.xlsx',2);
A=Label2(:,1);                             %农田样本在影像中的行数
B=Label2(:,2);                             %农田样本在影像中的列数
Label_tr1(sub2ind(size(Label_tr1),A,B))=2; %将样本点在0矩阵中赋值为2
% 建筑物样本标记为3
[Label3]=xlsread('J:\2022HFC_dry\GF_R24\r24_trainsamples.xlsx',3);
A=Label3(:,1);                             %城市样本在影像中的行数
B=Label3(:,2);                             %城市样本在影像中的列数
Label_tr1(sub2ind(size(Label_tr1),A,B))=3; %将样本点在0矩阵中赋值为3
% 山体阴影样本标记为4
[Label4]=xlsread('J:\2022HFC_dry\GF_R24\r24_trainsamples.xlsx',4);
A=Label4(:,1);                             %山体样本在影像中的行数
B=Label4(:,2);                             %山体样本在影像中的列数
Label_tr1(sub2ind(size(Label_tr1),A,B))=4; %将样本点在0矩阵中赋值为4
% 裸土样本标记为5
[Label5]=xlsread('J:\2022HFC_dry\GF_R24\r24_trainsamples.xlsx',5);
A=Label5(:,1);                             %裸土样本在影像中的行数
B=Label5(:,2);                             %裸土样本在影像中的列数
Label_tr1(sub2ind(size(Label_tr1),A,B))=5; %将样本点在0矩阵中赋值为5
gt=reshape(Label_tr1,[],1);                %二维矩阵转一维,是所有样本行号的统计矩阵
[~,~,class]=find(unique(gt));              %返回gt中的不重复值的位置
Label1 = uint16(Label1);
Label2 = uint16(Label2);
Label3 = uint16(Label3);
Label4 = uint16(Label4);
Label5 = uint16(Label5);
Label_tr1 = uint16(Label_tr1);
gt = uint16(gt);
% 用以检验样本导入是否成功
Spsnum_1=length(find((Label_tr1)==1));
Spsnum_2=length(find((Label_tr1)==2));
Spsnum_3=length(find((Label_tr1)==3));  % 若要减少样本数量时，该代码可删
% Spsnum_3=0;
Spsnum_4=length(find((Label_tr1)==4));
Spsnum_5=length(find((Label_tr1)==5));
YBFB(1,1)=Spsnum_1;
YBFB(2,1)=Spsnum_2;
YBFB(3,1)=Spsnum_3;
YBFB(4,1)=Spsnum_4;
YBFB(5,1)=Spsnum_5;
YBFB(1,2)=single(Spsnum_1)/(Spsnum_1+Spsnum_2+Spsnum_3+Spsnum_4+Spsnum_5);  % YBFB=样本分布， 最后一行为样本总数
YBFB(2,2)=single(Spsnum_2)/(Spsnum_1+Spsnum_2+Spsnum_3+Spsnum_4+Spsnum_5);
YBFB(3,2)=single(Spsnum_3)/(Spsnum_1+Spsnum_2+Spsnum_3+Spsnum_4+Spsnum_5);
YBFB(4,2)=single(Spsnum_4)/(Spsnum_1+Spsnum_2+Spsnum_3+Spsnum_4+Spsnum_5);
YBFB(5,2)=single(Spsnum_5)/(Spsnum_1+Spsnum_2+Spsnum_3+Spsnum_4+Spsnum_5);
YBFB(6,1)=Spsnum_1+Spsnum_2+Spsnum_3+Spsnum_4+Spsnum_5;
clear Spsnum_1 Spsnum_2 Spsnum_3 Spsnum_4 Spsnum_5 
timetik= '8.3 学习样本标签处理完毕';
disp(timetik);
%% 8.3.2 分步采样,单独运行每节，速度较快 （可与8.3.1合理替换）
[~,yy]=size(datasource);
perf=0.9;                                   % 指定选取样本的比例(可以尝试10%-90%),一般选取0.5-0.7之间
train_label1=zeros(length(gt),1,'uint16');
test_label=gt; 
train_sample=zeros(length(gt),yy,'single');
test_sample=zeros(length(gt),yy,'single');
[classNum,~] = size(class);
%
[a1,~]=size(Label1);
[a2,~]=size(Label2);
[a3,~]=size(Label3);
[a4,~]=size(Label4);
[a5,~]=size(Label5);
order_a = [a1 a2 a3 a4 a5];   % 代表着每类样本的总数，与采样率乘积即为学习样本个数，由于各类样本总数均不同，所以乘积结果有所不同
% 带有下标的赋值维度不等,因此直接采用速度最快的读取方式,yc系列也是检验gt中数量的
[yc1,~,~]=find(gt==class(1));
[yc2,~,~]=find(gt==class(2));
[yc3,~,~]=find(gt==class(3));
[yc4,~,~]=find(gt==class(4));
[yc5,~,~]=find(gt==class(5));
index_1=randperm(length(yc1));     % 随机排序后的样本标签
index_2=randperm(length(yc2));
index_3=randperm(length(yc3));
index_4=randperm(length(yc4));
index_5=randperm(length(yc5));
order1= ceil(perf*order_a);        % 确定各样本个数 
% 
qybq1= index_1(1:order1(1))';      % 按照采样比例确定样本行列号
qybq2= index_2(1:order1(2))';
qybq3= index_3(1:order1(3))';
qybq4= index_4(1:order1(4))';
qybq5= index_5(1:order1(5))';
BQ1=yc1(qybq1,1); 
BQ2=yc2(qybq2,1); 
BQ3=yc3(qybq3,1); 
BQ4=yc4(qybq4,1); 
BQ5=yc5(qybq5,1);
% 河流水体样本1
train_label1(BQ1)=class(1); 
train_sample(BQ1,:)=datasource(BQ1,:);
% 农田耕地样本2
train_label1(BQ2)=class(2); 
train_sample(BQ2,:)=datasource(BQ2,:);
% 城市建筑样本3
train_label1(BQ3)=class(3); 
train_sample(BQ3,:)=datasource(BQ3,:);
% 山体阴影样本4
train_label1(BQ4)=class(4); 
train_sample(BQ4,:)=datasource(BQ4,:);
% 山体植被样本5
train_label1(BQ5)=class(5); 
train_sample(BQ5,:)=datasource(BQ5,:);
%% 去掉标签中的0,从这里开始train_label和train_sample第一次出现行数不同
[index1,~,train_label]=find(train_label1);  % [a,b,v] = find(A)，找出A中非零元素所在的行和列，分别存储在a和b中，并将结果放在v中
% [index2,~,test_label]=find(test_label);    % index2存储着测试样本的行号，可反查
% 获取测试样本的属性矩阵
% for i=1:length(index2)
%   test_sample(index2(i),:)=datasource(index2(i),:);
% end;
% 去掉属性矩阵中整行都为0的,防止把个别列为0的删除使学习出错，这里后train_label和train_sample行数相同
row1 = find(all(train_sample ==0,2));        
% row2 = find(all(test_sample ==0,2));
train_sample(row1,:) = [];
% test_sample(row2,:) = [];
% 查找全为NAN的行,并在标签和数据中全部删除,针对 GLCM 数据使用
row3 = find(all(isnan(train_sample),2));   % 返回整行都是NAN的
% row4 = find(all(isnan(test_sample),2));
train_label(row3,:) = [];
train_sample(row3,:)= [];
% test_label(row4,:) = [];
% test_sample(row4,:)= [];
train_sample(isnan(train_sample))=0;    %随机森林参数中不能有NAN要将其改为其他值，本算例改为0
% test_sample(isnan(test_sample))=0;
train_sample = double(train_sample);
train_label = double(train_label);
% test_sample = double(test_sample);
row1 = single(row1);                    %改变存储类型，减少内存损耗
% row2 = single(row2);
row3 = single(row3);
% row4 = single(row4);
%% 将 datasource 变成测试集进行整体分类了
row5 = find(all(isnan(datasource),2));         % 将整行都是NAN的行号记录下来.并且 row,gt的类型均需要是double才行
datasource(row5,:) = [];
datasource = double(datasource);
datasource(isnan(datasource)) = 0;             % datasource里的nan都要改为0
%
clear train_label1 index_1 index_2 index_3 index_4 index_5 qybq1 qybq2 qybq3 qybq4 qybq5 BQ1 BQ2 BQ3 BQ4 BQ5 a1 a2 a3 a4 a5
timetik= '8.3.1 正式训练样本导入成功';
disp(timetik);
%% 8.4 RF函数训练测试，可先进行预实验测试随机森林预设参数 51.5万 x 12 列的训练样本可以正常运行
model = classRF_train(train_sample,train_label,1100,4,'importance localImp');
timetik= '8.4 RF正式模型训练完毕';
disp(timetik);
save('J:\2022HFC_dry\GF_R24\gfR24_RF.mat','model');
timetik= '8.4.1 RF模型存储完毕';
disp(timetik);

%% 9 正式并行分类前预处理阶段
[q2,~]=size(datasource);
zz=20;                                   %并行运算分块数,最好是核数60的整数倍但60核并行会报错，分成40份暂时可行
q3 = fix(q2/zz);
q31= rem(q2,zz);
Q = zeros(zz,1,'double');                %数组用来引导parfor
Q(1)=1;
%
for i = 1:(zz-1)
    Q(i+1) = i*q3+1;
end 
Test_Pred = zeros(q3+q31,zz,'double');   % 因为不能均分为4份，因此要拓充索引，不然会在赋值时报错，拓充的部分表达为0。再在合并的时候去掉0
data = zeros(q3+q31,yy,zz,'double');
% i=zz 一般出现问题，i=1:zz-1 一般都没有问题
for i =1:zz
    if i == zz
        data(:,:,i)= datasource(Q(i):q2,:); 
    else
        data(1:q3,:,i)= datasource(Q(i):i*q3,:);   % q3+1:q3+q31的部分则全是0
    end
end
%
clear datasource
timetik= '9. RF模型分类前，并行化分块已完成';
disp(timetik);
% clear q2 q3 q31 Q Test_Pred data 
%% 9.1 并行计算RF,目前并行
% clear datasource
corenum=2;                                  % 调用60核运算，共有64核,并行20已测试可行,
parpool('local',corenum);
%%
parfor i =1:zz
    i
    [Test_Pred(:,i),~] = classRF_predict(data(:,:,i),model);
end
timetik= '并行预测已完成';
disp(timetik);
% 测试单块能不能正常运行
% ddata=data(:,:,1);               
% ttestpred=Test_Pred(:,1);
% [ttestpred,~] = classRF_predict(ddata,model);
% （选）8.2 传统运行RF，效率较并行化低 
% [Test_Pred,votes] = classRF_predict(datasource,model);
%% 9.2 将分块结果整合为1
for i =1:zz
    if i == zz
       ttp2 = Test_Pred(:,i); 
    else
       ttp(:,i) = Test_Pred(:,i);
    end
end
ttp(q3+1:q3+q31,:) = [];    %将填补
tp = zeros(q2,1,'uint16');
ttp1=reshape(ttp,[],1);
[nttp1,~]=size(ttp1);
tp(1:nttp1,1)=ttp1;
tp(nttp1+1:q2,1)=ttp2;              % tp就是去零后的最终结果
% 
TestPred_BF = Test_Pred;            % 备份初次预测结果
clear Test_Pred
Test_Pred = tp;                     % 重新为test_Pred赋值
timetik= '分块结果整合已完成';
disp(timetik);
% Test_Pred = reshape(Test_Pred,[],1);    % 将分成的8块reshape成1列最终结果
% row6 = find(all(Test_Pred ==0,2));      % 找到是0的行数，并把这些行删去得到与 datasource 匹配的维度的 标签 进行后续操作
% Test_Pred(row6,:) = []; 
%% 10 准备输出数据并校验
gt1 = zeros(size(tp),'double');         % 复原预测结果，进行输出
% row5 = find(all(isnan(datasource),2));  
% clear datasource
gt1(row5,1)= nan;                       % 被选中的8个参数组成的datasat中整行NAN的部分
[row7,~] = find(~isnan(gt1));           % c=size(A,2) 该语句返回的是矩阵A的列数,找到非NAN行数。
gt1(row7,:) = Test_Pred;                % 将预测结果依次赋值给原始标签数组
Result1 = reshape(gt1,q1,t1); % 得出真实标签值，等待使用 corGF 的地理信息输出为图像
timetik= '10. tif格式矩阵整理完毕等待输出';
disp(timetik);
%% 10.1 输出图像
% 将Result1中的NAN要转换成0
Result1(find(isnan(Result1)==1)) = 0; 
% 记录GF地理信息并输出
geotiffwrite('H:\RemotesensingImagery\HFC_Dryseason\RFresults\0521RF_HFC210v1.tif',Result1,corGF,'GeoKeyDirectoryTag',info.GeoTIFFTags.GeoKeyDirectoryTag);
timetik= '10.1 tif格式输出完毕';
disp(timetik);
%% 10.2 从Result1中抽出我们早先excel中的样本来，再进行对比
A1 = Result1(sub2ind(size(Result1),Label1(:,1),Label1(:,2)));
[row8,~] = find(isnan(A1));
A1(row8,:) = [];
A2 = ones(size(A1),'double');
length(find((A1-A2)~=0))
%% 11. 校验各类型是否存在
length(find((Test_Pred)==1))
length(find((Test_Pred)==2))
length(find((Test_Pred)==3))
length(find((Test_Pred)==4))
length(find((Test_Pred)==5))
%% 11.1 检验结果，分类精度, 用5%的训练样本检测
test_pre = gt1(index2,:);              % 从整个影像的分类结果中抽出之前5%样本的相应类别进行比较
[row7,~] = find(isnan(test_pre));      % 之前的标签是经过去0处理的，体现再test_pre中就是去掉由0转化来的NAN
test_pre(row7,:) = [];                
test_label = double(test_label);
Result_Pred(:,1)=test_label;
Result_Pred(:,2)=test_pre;
Num_Water = length(find(test_pre== 1));
Num_Crop = length(find(test_pre == 2));
Num_City = length(find(test_pre == 3));
Num_Mount = length(find(test_pre == 4));
Num_Soil = length(find(test_pre == 5));
Num_Water1 = length(find(test_label == 1));
Num_Crop1 = length(find(test_label == 2));
Num_City1 = length(find(test_label == 3));
Num_Mount1 = length(find(test_label == 4));
Num_Soil1 = length(find(test_label == 5));
cMat = confusionmat(test_label,test_pre);
d=sum(diag(cMat));
Ci=sum(cMat,1);
Cj=sum(cMat,2);
q=Ci*Cj/length(test_label);
kappa=(d-q)/(length(test_label)-q)                                  % 卡帕系数
Accu = length(find(test_pre == test_label)) / length(test_label)    % 总体精度
Accu_W = Num_Water/Num_Water1                                       % 水体分类精度
%%
clear Test_Pred Result_Pred Num_Water Num_Crop Num_City Num_Mount Num_Soil Num_Water1 Num_Crop1 Num_City1 Num_Mount1 Num_Soil1 cMat d Ci Cj c kappa Accu Accu_W


%% 附件A. 预实验部分：随机森林中决策树棵数、次特征数 对性能的影响，此处是次特征数检验，将i 变成  i = 500:100:2000 则可以变成预实验棵树
I(1,:) = 16:8:64;
[~,N]= size(I);
Accuracy = zeros(1,N);
Kappa_Mean = zeros(1,N);
%%
for i = 16:8:64                    %% 并行运算开启
    i                          %同时也是计数器
    accuracy = zeros(1,50);       %每种情况，运行50次，取平均值
    kappa1 = zeros(1,50);
    parfor k = 1:50
        % 创建随机森林
        model = classRF_train(Train_Sample,train_label,1000,i);
        % 仿真测试
        T_pre = classRF_predict(Test_Sample,model);
        accuracy(k) = length(find(T_pre == test_label)) / length(test_label);
        cMat = confusionmat(test_label,T_pre);
        d=sum(diag(cMat));
        Ci=sum(cMat,1);
        Cj=sum(cMat,2);
        q=Ci*Cj/length(test_label);
        kappa1(k)=(d-q)/(length(test_label)-q);
    end
     Accuracy(i) = mean(accuracy);
     Kappa_Mean(i) = mean(kappa1);
end;

%% 附件B. GF等4波段卫星分类指数库 
% 51种水体指数，2种多尺度奇点指数，4个单波段，32个纹理指数，DEM，衍生出的Slope及方向 --------- 92种，3类
CI = zeros(q1,t1,'single');
CVI = zeros(q1,t1,'single');
NDVI = zeros(q1,t1,'single');
GDVI = zeros(q1,t1,'single');
WDVI = zeros(q1,t1,'single');
SRRed_NIR = zeros(q1,t1,'single');
Fe3 = zeros(q1,t1,'single');                       
CRI550 = zeros(q1,t1,'single');                    
NCWI = zeros(q1,t1,'single');
PBNDVI = zeros(q1,t1,'single');
D678 = zeros(q1,t1,'single');
SWI = zeros(q1,t1,'single');
ESWI = zeros(q1,t1,'single');
NCWI = zeros(q1,t1,'single');
GNDVI = zeros(q1,t1,'single');
RVI = zeros(q1,t1,'single');
EVI = zeros(q1,t1,'single');
DVI = zeros(q1,t1,'single');
RDVI = zeros(q1,t1,'single');
PNDVI = zeros(q1,t1,'single');
PBNDVI = zeros(q1,t1,'single');
BNDVI = zeros(q1,t1,'single');
ATSAVI = zeros(q1,t1,'single');
TSAVI = zeros(q1,t1,'single');
IO = zeros(q1,t1,'single');
BWDRVI = zeros(q1,t1,'single');
VARIgreen = zeros(q1,t1,'single');
RI = zeros(q1,t1,'single');
SR550 = zeros(q1,t1,'single');
D678 = zeros(q1,t1,'single');
IPVI = zeros(q1,t1,'single');

%  51种水体指数
ATSAVI 	=	 1.22*(band4-1.22*band3-0.03)./(1.22*band4+band3-1.22*0.03+0.08*(1.0+1.22.^2));
BNDVI 	=	 (band4-band1)./(band4+band1);
BWDRVI 	=	 (0.1*band4-band1)./(0.1*band4+band1);
CI 	=	 (band3-band1)./band3;
CRI550 	=	 band1.^(-1)-band2.^(-1);
D678 	=	 band3-band1;
DVI 	=	 band4-band3 ;
ESWI 	=	 (band1+band2)./(band4+band4);
Fe3 	=	 band3./band2;
GDVI 	=	 band4-band2;
GNDVI 	=	 (band4-band2)./(band4+band2);
IF 	=	 (2*band3-band2-band1)./(band2-band1);
IO 	=	 band3./band1;
NCWI 	=	 (7*band2-2*band1-5*band4)./(7*band2+2*band1+5*band4);
NDVI 	=	 (band4-band3)./(band4+band3);
PBNDVI 	=	 (band4-(band3+band1))./(band4+(band3+band1));
PNDVI 	=	(band4-(band2+band3+band1))./(band4+(band2+band3+band1));
RDVI 	=	(band4-band3)./(band4+band3).^0.5;
RI 	=	 (band3-band2)./(band3+band2);
RVI 	=	 band4./band3;
SR520 	=	 band1./band3;
SR550 	=	 band2./band4;
SR800 	=	 band4./band2;
SRRed_NIR 	=	 band3./band4;
SWI 	=	 band1+band2-band4;
TSAVI 	=	 (0.743*(band4-0.743*band3-0.323))./(band3+0.743*(band4-0.323)+0.413*(1+0.743^2));
VARIgreen 	=	 (band2-band3)./(band2+band3-band1);
WDVI 	=	 band4-0.46*band3;
AVI	=	 2*band4-band3; 
ARVI2	= -0.18+1.17*((band4-band3)./(band4+band3));
CIg	=	band4./band2-1;
CIr	=	band4./band3-1;
CVI	=	band4.*band3./band2.^2;
CTVI	= ((band4-band3)./(band4+band3)+0.5)./abs((band4-band3)./(band4+band3)+0.5).*sqrt(abs((band4-band3)./(band4+band3)+0.5));
DVIM	=	 2.4*band4-band3; 
GARI	=	2.0*(band1-band3)./((band4+band3)-(band1+band2))+1;
GRNDVI	=	(band4-band2-band3)./(band4+band2+band3);
Hue	=	atan((2*band3-band2-band1).*(band2-band1)/30.5);
IPVI	=	(0.5*band4./(band4+band3)).*RI;
I	=	(band2+band3+band1)/30.5;
mCRI	=	band4./(band1.^(-1)-band2.^(-1));
mCARI1	=	1.2*(2.5*(band4-band3)-1.3*(band4-band2));
MSAVI	=	(2*band4+1-sqrt((2*band4+1).^2-8*(band4-band3)))*0.5;
NLI	=	(band4.^2-band3)./(band4.^2+band3);
OSAVI	=	1.16*(band4-band3)./(band4+band3+0.16);
SARVI2	=	(band4-band3)./(1+band4+6*band3-7.5*band1)*2.5;
SAVI	=	1.5*(band4-band3)./(0.5+band4+band3);
SBL	=	band4-2.4*band3;
SPVI	=	1.48*(band4-band3)-1.2*abs(band2-band3);
TVI	=	sqrt(NDVI+0.5);
WDRVI	=	(0.1*band4-band3)./(0.1*band4+band3);