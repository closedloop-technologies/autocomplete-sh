Autocomplete.sh
========================================================
## `--help` less, accomplish more: Command your terminal

`autocomplete` adds intelligent command-line suggestions  for you directly in the terminal.  Just type <TAB><TAB> and it calls an LLM (OpenAI by default) and returns the top suggestions for you.

![intro_example1](https://github.com/user-attachments/assets/6f2a8f81-49b7-46e9-8005-c8a9dd3fc033)

## Installation

```bash
wget -qO- https://autocomplete.sh/install.sh | bash
```

## Supported Models
We current support OpenAI, Groq, Anthropic and Ollama models.

```bash
autocomplete model
```

![autocomplete-model](https://github.com/user-attachments/assets/6206963f-81c2-4d68-b054-6ec88969ba0c)

After selecting the model, the full configuration will be displayed (endpoint, costs, api key, ...)

![image](https://github.com/user-attachments/assets/74de61f6-a1fe-4b7c-80e5-14d222848288)

To change any of these, see the Configuration section below

## How it works

It's **faster** than copy-pasting from Stack Overflow and ChatGPT.

The suggestions are **more accurate** since we've engineered the prompts to contain limited information of your terminal's state including:
 * What kind of machine you are using: `$USER, $PWD, $OLDPWD, $HOME, $OSTYPE, $BASH, $TERM, $HOSTNAME`
 * `env` - Which variables are defined (but just the names and not the values)
 * `history` - Recently executed commands
 * `ls` - Recently modified files in the current directory
 * `--help` - any additional help information for the current command

If you are curious, you can see the full prompt using
```
autocomplete command --dry-run "anything you want here"
```
[Pull Requests](https://github.com/closedloop-technologies/autocomplete-sh/pulls) are welcome if you want to make it better!

By default we cache the last 20 requests to reduce latency and costs.

### Configuration

```bash
. autocomplete config
# or
source autocomplete config
```
Note you have to in order to determine if the autocomplete is enabled

![image](https://github.com/user-attachments/assets/61578f27-594f-4bc4-ba86-c5f99a41e8a9)

Configurations can be changed manually with
```bash
autocomplete config set <key> <value>
```
For example `autocomplete config set api_key sk-p...` will update your API key.

`autocomplete config reset` will restore config to the default values

### Tracking Usage
```bash
autocomplete usage
```
![image](https://github.com/user-attachments/assets/0fc611b9-fb4c-4f68-bf01-8e6ecdcf7410)

The average cost for me is about half a penny per request using the latest **gpt-4-omni** model.

The next section has instructions for the lower cost **gpt-3.5-turbo** model.

### Model Selection GPT-3.5-turbo Settings
GPT 3.5 has a lower cost model that is still quite effective.
It costs about 10-20 calls per $0.01

Run the following commands to switch to the lower cost model
```bash
autocomplete config set model gpt-3.5-turbo
autocomplete config set api_prompt_cost 0.0000005
autocomplete config set api_completion_cost 0.0000015
```

As always `--help` will get you more
```bash
autocomplete --help
```

![image](https://github.com/user-attachments/assets/5db7dd35-0436-4e8e-a474-87de9a60cda9)


## Use Cases

< TODO Replace each persona with a GIF of completions and the before + after text completions.  Use [USAGE.md](USAGE.md)>

### Data Engineer
Quickly manipulate datasets in the terminal to efficiently complete data transformations and move on to analysis or further processing.

```bash
ls
awk -F',' '{print $1}' data.csv | grep 'keyword'
spark-submit --master yarn my_script.py --input data.csv --output results/
python -c "import pandas as pd; df1 = pd.read_csv('data1.csv'); df2 = pd.read_csv('data2.csv'); merged_df = pd.merge(df1, df2, on='key_column'); merged_df.to_csv('merged_data.csv', index=False)"
```

### Backend Developer
Swiftly deploy updates and focus on improving your codebase.

```bash
git init
gcc -o output_file input_file.c
pytest tests/
docker build -t my_image .
docker run -d -p 8080:80 my_image
```

### Linux User
- Effortlessly navigate and control your system for seamless administration.
```bash
top
sudo apt install package_name
chmod 755 script.sh
sudo systemctl start service_name
```

### Terminal Novice
Build confidence and proficiency with every command.

```bash
cd path/to/directory
touch new_file.txt
cp file.txt destination/
cat file.txt
```

### Efficiency Seeker
Streamline tasks and reclaim valuable time for what matters most.

```bash
sed -i 's/old_text/new_text/g' *.txt
tar -czvf archive.tar.gz directory/
tar -xzvf archive.tar.gz
cat file.txt | grep 'keyword' | wc -l
```

### Documentation Seeker
Resolve issues and understand commands with ease.

```bash
man command_name
apropos keyword
help
dpkg -l | grep package_name
```

## Development

Install locally

```bash
git clone git@github.com:closedloop-technologies/autocomplete-sh.git
# Create a symlink to install the script in your path
ln -s $PWD/autocomplete.sh $HOME/.local/bin/autocomplete
# Run the install script
. autocomplete.sh install
```

Pre Commit Hooks for shellcheck

    pip install pre-commit
    pre-commit install

Tests via Bats

    sudo apt install bats
    bats tests

Test Installation via Docker

    docker build -t autocomplete-sh .

    # To run tests
    docker run --rm -e OPENAI_API_KEY=$OPENAI_API_KEY autocomplete-sh

    # To use the autocomplete manually - requires manually installing it once inside the container
    docker run --rm -it \
       -e OPENAI_API_KEY=$OPENAI_API_KEY \
       --entrypoint /bin/bash \
       autocomplete-sh

    autocomplete --help

### Inspiration

 * [NVM](https://github.com/nvm-sh/nvm/tree/master)
 * [OpenCommit](https://github.com/di-sukharev/opencommit)
 * [Omakub](https://omakub.org/)

## Maintainers

Currently maintained by Sean Kruzel [@closedloop](https://github.com/closedloop) as a member of [Closedloop.tech](https://Closedloop.tech)

More maintainers and bug fixers are quite welcome, and we hope to grow the community around this project.
Governance will be re-evaluated as the project evolves.

### Support Open Source
Although writing 1,049 lines of bash was its own "reward", if you tried it and love it please show your support here!

[!["Buy Me A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/skruzel)


## License

See the [LICENSE](./LICENSE) file for details.
