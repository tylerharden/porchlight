mod config;
mod model;
mod scanner;
mod state;

use clap::{Parser, Subcommand};
use config::Config;
use state::StateError;

#[derive(Parser)]
#[command(name = "porchlight")]
#[command(about = "Find the servers you left on.")]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// List local servers.
    List {
        /// Print machine-readable JSON.
        #[arg(long)]
        json: bool,
    },
    /// Show configuration.
    Config {
        #[command(subcommand)]
        command: ConfigCommands,
    },
}

#[derive(Subcommand)]
enum ConfigCommands {
    /// Show the effective configuration.
    Show,
}

fn main() {
    if let Err(error) = run() {
        eprintln!("porchlight: {error}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), PorchlightError> {
    let cli = Cli::parse();
    let config = Config::default();

    match cli.command.unwrap_or(Commands::List { json: false }) {
        Commands::List { json } => {
            let active_servers = scanner::scan(&config)?;
            let mut state = state::AppState::load()?;
            let servers = state.merge_servers(active_servers, &config);
            state.save()?;

            if json {
                let response = model::ServerList { servers };
                println!(
                    "{}",
                    serde_json::to_string_pretty(&response).expect("server list serializes")
                );
            } else if servers.is_empty() {
                println!("No local servers found.");
            } else {
                for server in servers {
                    let path = server
                        .display_directory
                        .as_deref()
                        .unwrap_or("Unknown directory");
                    println!(
                        "{}\t{}\t{}\tpid {}\t{}",
                        server.port, server.server_type, server.process_name, server.pid, path
                    );
                }
            }
        }
        Commands::Config { command } => match command {
            ConfigCommands::Show => {
                println!(
                    "{}",
                    serde_json::to_string_pretty(&config).expect("config serializes")
                );
            }
        },
    }

    Ok(())
}

#[derive(Debug, thiserror::Error)]
enum PorchlightError {
    #[error(transparent)]
    Scanner(#[from] scanner::ScannerError),
    #[error(transparent)]
    State(#[from] StateError),
}
