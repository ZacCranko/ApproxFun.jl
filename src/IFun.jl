## transforms





function chebyshevtransform(x::Vector)
    ret = FFTW.r2r(x, FFTW.REDFT00);
    ret[1] *= .5;
    ret[end] *= .5;    
    ret.*alternatingvector(length(ret))/(length(ret)-1)
end

function ichebyshevtransform(x::Vector)
    x[1] *= 2.;
    x[end] *= 2.;
    
    ret = chebyshevtransform(x);
    
    x[1] *= .5;
    x[end] *= .5;
    
    ret[1] *= 2.;
    ret[end] *= 2.;
    
    flipud(ret.*alternatingvector(length(ret)).*(length(x) - 1).*.5)
end





##  Constructors




type IFun{T<:Number,D<:IntervalDomain} <: AbstractFun
    coefficients::Vector{T}
    domain::D
end




IFun(f::Function,n::Integer)=IFun(f,Interval(),n)
IFun(f::Function,d::Domain,n::Integer)=IFun(chebyshevtransform(f(points(d,n))),d)
IFun(f::Function,d::Vector,n::Integer)=IFun(f,apply(Interval,d),n)
IFun(cfs::Vector)=IFun(cfs,Interval())
IFun(cfs::Vector,d::Vector)=IFun(cfs,apply(Interval,d))
IFun(f::Function)=IFun(f,Interval())
IFun(f::Function,d::Vector)=IFun(f,apply(Interval,d))


function IFun(f::Function, d::Domain)
    #reuse function values

    tol = 200*eps();

    oldcf = IFun(f,d,2 + 1);

    for logn = 2:20
        cf = IFun(f, d, 2^logn + 1);
        
        if max(abs(cf.coefficients[end]),abs(cf.coefficients[end-1]),max(abs(cf.coefficients[1:2^(logn-1) + 1] - oldcf.coefficients))) < tol
            chop!(cf,10eps());
            return cf;
        end
        
        oldcf = cf;
    end
    
    warn("Maximum length reached");
    
    cf
end


##Evaluation


Base.getindex(f::IFun,x)=evaluate(f,x)
evaluate(f::IFun,x)=clenshaw(f.coefficients,tocanonical(f.domain,x))





function clenshaw(c,x)
    if max(abs(imag(x))) < 10*eps()
        clenshaw(c,real(x))
    else
        clenshaw(c,real(x))+im*clenshaw(c,imag(x))    
    end
end

function clenshaw(c::Vector,x::Real)

    x = 2x;
    bk1 = 0.0;
    bk2 = 0.0;
    for k = length(c):-1:2
        bk2, bk1 = bk1, c[k] + x * bk1 - bk2
    end

    c[1] + 0.5 * x * bk1 - bk2
end

using NumericExtensions

function clenshaw{T<:Number,M<:Real}(c::Vector{T},x::Vector{M})
    n = length(x)
    bk1 = zeros(n)
    bk2 = zeros(n)
    x=2x
    
    @assert length(c) > 0 
    bk =  Array(T,n) 

    x_v = unsafe_view(x)
    bk1_v = unsafe_view(bk1)
    bk2_v = unsafe_view(bk2)
    bk_v = unsafe_view(bk)

    for k in  length(c):-1:2
        @inbounds ck = c[k]
        for i in 1 : n
            bk_v[i] = ck + x_v[i] * bk1_v[i] - bk2_v[i]
        end
        bk2_v, bk1_v, bk_v = bk1_v, bk_v, bk2_v
    end

    @inbounds ce = c[1]
    for i in 1 : n
        bk[i] = ce + .5 * x_v[i] * bk1_v[i] - bk2_v[i]
    end
    
    bk
    
#     ## Hack to corect the fact bk_v keeps changing    
#     for i in 1 : n
#         bk_v[i] = ce + .5 * x_v[i] * bk1_v[i] - bk2_v[i]
#     end
#     
# 
#      j = mod(length(c), 3)
#     j == 0 ? bk1 : j == 1 ? bk : bk2
end






##Data routines
values(f::IFun)=ichebyshevtransform(f.coefficients) 

points(f::IFun)=points(f.domain,length(f))


Base.length(f::IFun)=length(f.coefficients)



## Matipulate length


pad!(f::IFun,n::Integer)=pad!(f.coefficients,n)
pad(f::IFun,n::Integer)=IFun(pad(f.coefficients,n),f.domain)





function chop!(c::Vector,tol::Real)
    @assert tol > 0

    for k=[length(c):-1:1]
        if abs(c[k]) > tol
            resize!(c,k);
            return c;
        end
    end
    
    []
end

chop!(f::IFun,tol::Real)=chop!(f.coefficients,tol)
Base.chop(f,tol)=chop!(deepcopy(f),tol)


## Addition and multiplication




for op = (:+,:-)
    @eval begin
        function ($op)(f::IFun,g::IFun)
            @assert f.domain == g.domain
        
            n = max(length(f),length(g))
            f2 = pad(f,n);
            g2 = pad(g,n);
            
            IFun(($op)(f2.coefficients,g2.coefficients),f.domain)
        end

        function ($op)(f::IFun,c::Number)
            f2 = deepcopy(f);
            
            f2.coefficients[1] = ($op)(f2.coefficients[1],c);
            
            f2
        end
    end
end 



function .*(f::IFun,g::IFun)
    @assert f.domain == g.domain
    #TODO Coefficient space version
    n = length(f) + length(g) - 1;
    f2 = pad(f,n);
    g2 = pad(g,n);
    
    IFun(chebyshevtransform(values(f2).*values(g2)),f.domain)
end




for op = (:*,:.*,:./,:/)
    @eval ($op)(f::IFun,c::Number) = IFun(($op)(f.coefficients,c),f.domain)
end 

-(f::IFun)=IFun(-f.coefficients,f.domain)
-(c::Number,f::IFun)=-(f-c)


for op = (:*,:.*,:+)
    @eval ($op)(c::Number,f::IFun)=($op)(f,c)
end




# division by fun 

for op = (:./,:/)
    @eval begin
        function ($op)(c::Number,f::IFun)
            #TODO choose the length
        
            f2 = pad(f,2*length(f));
            
            f2 = IFun(chebyshevtransform(c/values(f2)),f.domain);
            
            if max(abs(f2.coefficients[end-1:end])) > 10*eps()
                warn("Division has not converged, may be inaccurate")
            end
            
            f2
        end
    end
end

./(f::IFun,g::IFun)=f.*(1./g)



## Norm

import Base.norm

norm(f::IFun)=real(sqrt(sum(f.*conj(f))))



## Mapped functions

import Base.imag, Base.real, Base.conj

for op = (:real,:imag,:conj) 
    @eval ($op)(f::IFun) = IFun(($op)(f.coefficients),f.domain)
end


## Differentiation and integration


## Start of support for UFun

# diff from T -> U
ultradiff(v::Vector)=[1:length(v)-1].*v[2:end]

#int from U ->T
ultraint(v::Vector)=[0,v./[1:length(v)]]



# Convert from U -> T
function ultraiconv(v::Vector{Float64})
    n = length(v);
    w = Array(Float64,n);
    
    w[end] = 2v[end];
    w[end-1] = 2v[end-1];
    
    for k = n-2:-1:2
        w[k] = 2*(v[k] + .5w[k+2]);
    end
    
    w[1] = v[1] + .5w[3];
    
    w
end


# Convert T -> U
function ultraconv(v::Vector{Float64})
    n = length(v);
    w = Array(Float64,n);
    
    if n == 1
        w[1] = v[1];
    elseif n == 2
        w[1] = v[1];
        w[2] = .5v[2];
    else
        w[1] = v[1] - .5v[3];        
    
        w[2:n-2] = .5*(v[2:n-2] - v[4:n]);
    
        w[n-1] = .5v[n-1];
        w[n] = .5v[n];        
    end
    
    w
end

ultraiconv(v::Vector{Complex{Float64}})=ultraiconv(real(v)) + ultraiconv(imag(v))*1.im
ultraconv(v::Vector{Complex{Float64}})=ultraconv(real(v)) + ultraconv(imag(v))*1.im




==(f::IFun,g::IFun) =  (f.coefficients == g.coefficients && f.domain == g.domain)



## Root finding


function complexroots(cin::Vector)
    c=chop(cin,10eps());
    if c == []
        return [];
    end
    
    n=length(c)-1;
    
    I = [ones(Int64,n),2:n-1,2:n];
    J=[1:n,3:n,1:n-1];
    V = [-c[end-1]/(2c[end]),.5-c[end-2]/(2c[end]),-c[end-3:-1:1]/(2c[end]),.5*ones(n-2),.5*ones(n-2),1];
    C=sparse(I,J,V);
    A=zeros(n,n);
    A[1:end,1:end]=C[1:end,1:end];
    
    Λ,V=eig(A);
    Λ
end


function complexroots(f::IFun)
    fromcanonical(f,complexroots(f.coefficients))
end

function roots(f::IFun)
    complexroots(f)
end


    
bisectioninv(f::IFun,x::Real) = first(bisection(f,[x]))

function bisectioninv(c::Vector{Float64},xl::Vector{Float64}) 
    n = length(xl);
    a = -ones(n);
    b = ones(n);
    
#     a_v = unsafe_view(a);
#     b_v = unsafe_view(b);    
    
    for k=1:47  #TODO: 
        m=.5*(a+b);
        vals = clenshaw(c,m);
        I1 = vals-xl.<=0; I2 = vals-xl.>0; 
        a = I1.*m + I2.*a;
        b = I1.*b + I2.*m;
    end
    m=.5*(a+b)    
end


## Sampling

function sample(f::IFun,n::Integer)
    cf = cumsum(f);
    cf = cf - cf[f.domain.a];
    cf = cf/cf[f.domain.b];
    
    fromcanonical(f,bisectioninv(cf.coefficients,rand(n)))
end



## Plotting


# function Winston.plot(f::IFun{Complex})
#     plot(points(f),values(real(f)),points(f),values(imag(f)))
# end

function plot(f::IFun{Float64}) 
    p = FramedPlot();
    pts = points(pad(f,2length(f)));
    vals =values(pad(f,2length(f)));
    add(p,Curve(pts,vals,"color","blue"));   
    Winston.display(p);
    p
end

function plot(f::IFun{Complex{Float64}}) 
    p = FramedPlot();
    pts = points(pad(f,2length(f)));
    vals =values(pad(f,2length(f)));
    add(p,Curve(pts,real(vals),"color","blue"));
    add(p,Curve(pts,imag(vals),"color","red"));    
    Winston.display(p);
    p
end






