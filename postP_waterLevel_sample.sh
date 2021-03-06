#!/bin/bash
## Executes the OF command "sample" for specific definitions in "system/sampleDict" to evaluate the water level (alpha.water = 0.5) along certain lines.
## ! Execute the script from OF_CASE_DIR/postProcessing/ directory !
## ! Adjust "OF_CASE_DIR/system/sampleDict" file befor evatuation !

echo -e ""
echo "postprocessing for the evaluation of the water level along certain lines"
echo "REMINDER: sampleDict checked?!"

if [ -d ../0 ]; then
	mv ../0 ../0.bak
fi

if [ ! -d ./waterLevel_sample ]; then
	mkdir waterLevel_sample
else
	rm waterLevel_sample/!(sample_output)
fi

## execute sample command
if [ -d ./sets ]; then
	read -p "-> The sets directory already exists. Do you want to run sample again and overwrite old data (y/n)? " ans1
	if [ "$ans1" == "y" ]; then
		rm -r sets
		echo "sampling and writing terminal output to file: sample_output"
		echo "..."
		cd ..
        sample > postProcessing/waterLevel_sample/sample_output
#        sample -time '20:30' > postProcessing/waterLevel_sample/sample_output
		cd postProcessing
	else
		rm sets/*/*.out3
	fi
else
	echo "sampling and writing terminal output to file: sample_output"
	echo "..."
	cd ..
	sample > postProcessing/waterLevel_sample/sample_output
#    sample -time '20:30' > postProcessing/waterLevel_sample/sample_output
	cd postProcessing
fi

echo "postprocessing of sampled data ..."

## make time range file
grep -F 'Time = ' waterLevel_sample/sample_output > waterLevel_sample/fltimes
grep -o '[^=^ ]\+$' waterLevel_sample/fltimes > waterLevel_sample/existingTimes

## list of sample lines
cd sets/*
ls | grep -F "_alpha.water.xy" | sed 's/_alpha.water.xy//g' > ../../waterLevel_sample/existingLines
cd ../..

## thin out of sampled data - delete every line with "e-" and "0"
for i in ./sets/*/*.xy; do
	sed -i '/e-/d' $i
	sed -i '/\s0$/d' $i
done

## thin out of sampled data - keep lines next to value "0.5"
for i in ./sets/*/*.xy; do
	awk '{if (NR>1 && $2 < 0.5 && prev2 > 0.5) {print prev1, prev2; print $1, $2} prev1=$1; prev2=$2}' $i > $i.out1
done

## keep line with maximal z values 
echo "Keeping only data for maximum z values if there are more water surfaces than one (bubbles)."
for i in ./sets/*/*.out1; do
	tail -n 2 $i > $i.out2
done

## interpolation of the z-coordinate to the exact value of alpha.water = 0.5 (water surface)  
for i in ./sets/*/*.out2; do
	awk '{if (NR>1) {x=0.5; x2=$2; y2=$1; y=(y2-y1)/(x2-x1)*(x-x1)+y1; print y, x} x1=$2; y1=$1}' $i > $i.out3
done

## define variables
lines=$(cat ./waterLevel_sample/existingLines)
times=$(cat ./waterLevel_sample/existingTimes)

## take value of third column for each timestep and list in one file
for line in $lines; do
    for time in $times; do
        cut -d" " -f1 ./sets/${time}/${line}_alpha.water.xy.out1.out2.out3 >> waterLevel_sample/waterLevel_temp_${line}
    done
done

## combine time and water surface in one file
for line in $lines; do
	paste waterLevel_sample/existingTimes waterLevel_sample/waterLevel_temp_${line} | awk '{print $1, $2}' >> waterLevel_sample/table_waterLevel_${line}
done

rm waterLevel_sample/waterLevel_temp_*
rm waterLevel_sample/fltimes
rm ./sets/*/*.out1
rm ./sets/*/*.out2

echo "plotting diagram"
gnuplot <<- EOF
    set terminal pngcairo size 1600,600 enhanced font 'Verdana,10'
    set title 'water level over time at sample line'
    set xlabel 'time [s]'
    set ylabel 'height [m]'
    set grid
    outfile = 'waterLevel_sample/waterLevel_diagram.png'
    set output outfile
    set key noenhanced
    lines = system('cat waterLevel_sample/existingLines')
    numLines = system('wc -l < waterLevel_sample/existingLines')
    #array linesArr[numLines]
    #array meanValArr[numLines]
    linesArr=''
    meanValArr=''
    set print 'waterLevel_sample/StatDat.dat'
    #i = 1
    do for [line in lines] {
        stats  'waterLevel_sample/table_waterLevel_'.line u 2 nooutput ;
        print STATS_mean
        linesArr = sprintf("%s %s",linesArr,line)
        meanValArr = sprintf("%s %.3f",meanValArr,STATS_mean)
        #i = i + 1
    }
    set print
    system('paste waterLevel_sample/existingLines waterLevel_sample/StatDat.dat > waterLevel_sample/meanValues.txt')
    print 'Mean values printed in file: waterLevel_sample/meanValues.txt'
    set key noenhanced
    set key outside
    set cbrange [0:100]
    unset colorbox
    plot for [i=1:numLines] 'waterLevel_sample/table_waterLevel_'.word(linesArr,i) with linespoints palette cb (i-1)*(100/numLines) title word(linesArr,i), \
        for [i=1:numLines] word(meanValArr,i)+0 palette cb (i-1)*(100/numLines) title word(meanValArr,i)
    print 'plot image to: '.outfile
EOF

rm waterLevel_sample/existingTimes
rm waterLevel_sample/existingLines
rm waterLevel_sample/StatDat.dat

echo "done"
echo -e ""
