echo > cvt.sed
for pdf in `ls *.pdf` 
do 
	echo "s/$pdf/$pdf/i" >> cvt.sed
done

gsed -f cvt.sed ../_pages/publications.md
