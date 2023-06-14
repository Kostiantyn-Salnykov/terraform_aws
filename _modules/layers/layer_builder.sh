mkdir ${layers_folder_name} && cd ${layers_folder_name}
mkdir ${layer_folder_name} && cd ${layer_folder_name}
mkdir ./${python_folder_name} && cd ${python_folder_name}
%{for lib in libraries }
pip install ${lib.name}%{if lib.version != ""}==${lib.version}%{ endif } -t .
%{ endfor }
cd ..
zip -r python.zip ./
