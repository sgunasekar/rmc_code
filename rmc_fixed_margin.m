%% X = RMC_exact_fixed_margin(ii,jj,Jcol,YOmega,eps,d1,d2)
% min ||X||_* st DX_j<= -eps_j 
% [Xest,spZest,stat]
function [Yest,iter,res]=rmc_fixed_margin(ii,Jcol,jj,YOmega,d1,d2,mu0,par)

Amap  = @(X,ii) Amap_MatComp(X,ii,Jcol);  
if (length(YOmega)/(d1*d2)>0.6)
    ATmap = @(y,ii) full(sparse(ii,jj,y, d1,d2));
else
    if (exist('mexspconvert')==3); 
        ATmap = @(y,ii) mexspconvert(d1,d2,y,ii,Jcol); 
    else
        ATmap = @(y,ii) sparse(ii,jj,y, d1,d2); 
    end
end

%% Initialize Variables
sv=20; 

global X spZ
rinit=10;
%eps=zeros(d2,1);
%for j=1:length(Jcol)-1
%    ind = Jcol(j)+1:Jcol(j+1);
%    eps(j) = max(1e-5,min(diff(YOmega(ind))));
%end
%eps=(1/d2)*ones(d2,1);
n=length(YOmega);
%compute epsilon
eps0=(1/d1);
eps=ones(n,1);
blk={};
for j=1:length(Jcol)-1
    ind = Jcol(j)+1:Jcol(j+1);
    Yj=diff(YOmega(ind));%diff(y)=y(i)-y(i+1)
    eps_temp=eps0*(Yj>0);
    eps(ind)=[0;cumsum(eps_temp)];
    
    %create blks
    f= find(eps_temp==0);
    sid=f(1);
    for i=2:length(f)
        if f(i)==f(i-1)+1
            continue
        else
            eid=f(i-1)+1;
            blk{length(blk)+1}=[ind(sid),ind(eid)];
            sid=f(i);
        end
    end
    eid=f(i)+1;
    blk{length(blk)+1}=[ind(sid),ind(eid)];
end
    
    
    

Yrt=YOmega;
X.U=zeros(d1,rinit);X.V=zeros(d2,rinit); 
XOmega=Amap(X,ii);
spZ=ATmap((Yrt-XOmega)/2,ii);
Xold=XOmega;
continuation_steps=1;
par.continuation=0.5;mu0=mu0/((par.continuation)^continuation_steps);
ch=0; res=0; mu=mu0;
for j=1:continuation_steps
    if res<par.tol && ch<par.tol
        mu=par.continuation*mu;    
        if ismember('mutarget', fieldnames(par))
            if mu<par.mutarget; mu=par.mutarget; end
        end
    else
        mu=sum(svd(X.U*X.V'+full(spZ))); par.continuation=1; 
    end
    
    for iter=1:par.maxiter
        %% UPDATE 
        if par.nnp
            sv=NNP_LR_SP(mu,min(sv,par.maxrank));
            XOmega=Amap(X,ii);
            Yrt=c_colMR_fixed_margin(((Yrt+XOmega)/2)',eps',Jcol); Yrt=Yrt'; 
            spZ=ATmap((Yrt-XOmega)/2,ii);     
        else
            sv=SVT_LR_SP(mu,sv,par);      
            fprintf('\t\t SVT: sv:%d,muX:%f\n',sv,sum(svd(X.U*X.V')));      
            
            ch=norm(Amap(X,ii)-Xold)/sqrt(n);
            Xold=Amap(X,ii);
            
            Yrt_temp=(Yrt+XOmega)/2;            
            [Yrt_temp,ii]=block_sort(Yrt_temp,ii,blk);
            Yrt=c_colMR_fixed_margin(Yrt_temp',eps',Jcol); Yrt=Yrt';  
            
            XOmega=Amap(X,ii); 
            spZ=ATmap((Yrt-XOmega)/2,ii);                       
        end  
        %% EXIT CONDITIONS
        res=norm(Yrt-XOmega);   
        %ch=norm(Xold-XOmega)/sqrt(length(XOmega));
        %Xold=XOmega;
        if par.verbose
            fprintf('\titer:%d,sv:%d,res:%f/%0.2g,ch:%f,muY:%f\n',...
                iter,sv,res,norm(spZ,'fro'),ch,sum(svd(X.U*X.V')))            
        end  

        if (res<par.tol || ch<par.tol)
            break
        end                
    end
    if (par.continuation>=1)
         break
    end  
end
Yest=X;

clear global