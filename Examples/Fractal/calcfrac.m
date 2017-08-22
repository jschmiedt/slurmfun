function Zout = calcfrac(cfg)

xpos = cfg.xpos;
ypos = cfg.ypos;
span = cfg.span;
steps = cfg.steps;

if span > 0.1
    maxiter=66;
else
    maxiter=-20*log(span)+100.*exp(span+1)-280;
end


for m=1:steps
    c=i.*(ypos-span./2+span.*m./steps);
    for n=1:steps
        c=xpos-span./2+span.*n./steps+i.*imag(c);
        z=c;
        for r=0:maxiter
            z=z.*z+c;
            if abs(z)>2
                break
            end
        end
        Zout(m,n)=r./maxiter;  %normalize to values between 0 and 1
    end
end
