ls -lAR | sort -nr -k5 | nl | head -n5 | awk '{print $1":"$6" "$10}END{system("ls -lAR")}' | awk '{if($1~/dr/) dir++;}; {if($1~/-r/) file++};{if($1~/-r/)total+=$5};{if($1~/^[1]/) print "--------\nFive largest files:"};{if($1~/^[0-9]/) print $1" "$2" "$3};END{print "--------\nDir num:"dir"\nFile num:"file"\nTotal:"total"\n--------"};'