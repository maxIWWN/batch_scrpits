#!/bin/bash

if [ -d ../0 ]; then
    mv ../0 ../0.bak
fi

echo -e "\n"
echo "sample for water level evaluation"

if [ ! -d ./waterLevel_sample ]; then
	mkdir waterLevel_sample
else
	rm waterLevel_sample/!(sample_output)
fi

if [ -d ./sets ]; then
	read -p "-> The sets directory already exists. Do you want to run sample again (y/n)? " ans1
	if [ "$ans1" == "y" ]; then
		rm -r sets
		echo "sampling and writing to file: sample_output"
		echo "..."
		cd ..
		sample > postProcessing/waterLevel_sample/sample_output
		cd postProcessing
	else
		rm sets/*/*.out3
	fi
else
	echo "sampling and writing to file: sample_output"
	echo "..."
	cd ..
	sample > postProcessing/waterLevel_sample/sample_output
	cd postProcessing
fi

echo "processing data"
echo "..."

## Zeitdatei erstellen  
grep -F 'Time = ' waterLevel_sample/sample_output > waterLevel_sample/fltimes
grep -o '[^=^ ]\+$' waterLevel_sample/fltimes > waterLevel_sample/existingTimes

## Liste der sampling lines
cd sets/*
ls | grep -F "_alpha.water.xy" | sed 's/_alpha.water.xy//g' > ../../waterLevel_sample/existingLines
cd ../..

## Ausdünnung der aufgenommen Werte 
for i in ./sets/*/*.xy; do
	sed -i '/e-/d' $i
	sed -i '/\s0$/d' $i
done

## Ausdünnung aufgenommen Werte 
for i in ./sets/*/*.xy; do
	awk '{if (NR>1 && $2 < 0.5 && prev2 > 0.5) {print prev1, prev2; print $1, $2} prev1=$1; prev2=$2}' $i > $i.out1
done

## nur maximal z Werte behalten
echo "Keeping only data for maximum z values if there are more water surfaces than one (bubbles)."
for i in ./sets/*/*.out1; do
	tail -n 2 $i > $i.out2
done

## Interpolation des z-Wertes der WSP-Lage auf exakt 0.5 (alpha.water)  
for i in ./sets/*/*.out2; do
	awk '{if (NR>1) {x=0.5; x2=$2; y2=$1; y=(y2-y1)/(x2-x1)*(x-x1)+y1; print y, x} x1=$2; y1=$1}' $i > $i.out3
done

## define variables
lines=$(cat ./waterLevel_sample/existingLines)
times=$(cat ./waterLevel_sample/existingTimes)

## Wert aus dritter Spalte für jeden Zeitschritt nehmen und in einer Datei auflisten
for line in $lines; do
    for time in $times; do
        cut -d" " -f1 ./sets/${time}/${line}_alpha.water.xy.out1.out2.out3 >> waterLevel_sample/waterLevel_temp_${line}
    done
done

## Zeit mit WSP verknüpfen
for line in $lines; do
	paste waterLevel_sample/existingTimes waterLevel_sample/waterLevel_temp_${line} | awk '{print $1, $2}' >> waterLevel_sample/table_waterLevel_${line}
done

rm waterLevel_sample/waterLevel_temp_*
rm waterLevel_sample/fltimes
rm ./sets/*/*.out1
rm ./sets/*/*.out2

## Erstellen eines Diagramms mit GnuPlot
echo "ploting diagram"
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
    plot for [line in lines] 'waterLevel_sample/table_waterLevel_'.line with linespoints title line
    print 'plot image generated: '.outfile
EOF

rm waterLevel_sample/existingTimes
rm waterLevel_sample/existingLines

echo "done"
echo -e ""
