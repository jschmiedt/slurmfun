function gid = primary_group()
[result, gid] = system('id -g ');
if result == 0 
    gid = str2double(gid);
else
    error('Could not determine primary group of user');
end