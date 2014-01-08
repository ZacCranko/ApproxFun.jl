export ToeplitzOperator


function Base.getindex(B::BandedOperator,k,j)
    A=ShiftArray(zeros(length(k),length(bandrange(B))),index(B))
    copybandedentries(B,A,1:length(k),0,1:length(bandrange(B)),0)
    BandedArray(A)[k,j]
end



type ToeplitzOperator{V<:Union(Vector,ShiftVector)} <: BandedOperator
    coefficients::V
end

ToeplitzOperator(f::AbstractFun)=ToeplitzOperator(f.coefficients)
index{M<:Vector}(T::ToeplitzOperator{M})=length(T.coefficients)
index{M<:ShiftVector}(T::ToeplitzOperator{M})=T.coefficients.index



#TODO: assert?
#TODO: we assume A is initialized to 0
function copybandedentries{M<:Vector}(T::ToeplitzOperator{M},A::ShiftArray,kr::Range1,ksh::Integer,jr::Range1,jsh::Integer)
    v = T.coefficients
    
    
    for k=kr,j=max(jr[1],1-length(v)):min(jr[end],length(v)-1)
        A[k+ksh,j+jsh] = (j ==0) ? 2v[1] : v[abs(j)+1]
    end
    
    A
end


bandrange{M<:Vector}(T::ToeplitzOperator{M})=(1-length(T.coefficients):length(T.coefficients)-1)



function copybandedentries{M<:ShiftVector}(T::ToeplitzOperator{M},A::ShiftArray,kr::Range1,ksh::Integer,jr::Range1,jsh::Integer)
    v = T.coefficients
    
    
    for k=kr,j=max(jr[1],range(v)[1]):min(jr[end],range(v)[end])
        A[k+ksh,j+jsh] = v[j]
    end
    
    A
end


bandrange{M<:ShiftVector}(T::ToeplitzOperator{M})=range(T.coefficients)

