use crate::config::Config;
use crate::model::{LocalServer, ServerStatus};
use crate::{scanner, state};
use crossterm::event::{self, Event, KeyCode, KeyEventKind};
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, Borders, Cell, Paragraph, Row, Table, TableState, Wrap};
use ratatui::{DefaultTerminal, Frame};
use std::io;
use std::process::Command;
use std::time::{Duration, Instant};

const REFRESH_INTERVAL: Duration = Duration::from_secs(2);

pub fn run(config: Config) -> Result<(), TuiError> {
    let mut terminal = TerminalSession::enter()?;
    let mut app = TuiApp::new(config);
    app.refresh()?;
    let result = app.run(&mut terminal.terminal);
    TerminalSession::leave()?;
    result
}

struct TerminalSession {
    terminal: DefaultTerminal,
}

impl TerminalSession {
    fn enter() -> Result<Self, TuiError> {
        Ok(Self {
            terminal: ratatui::init(),
        })
    }

    fn leave() -> Result<(), TuiError> {
        ratatui::restore();
        Ok(())
    }
}

impl Drop for TerminalSession {
    fn drop(&mut self) {
        ratatui::restore();
    }
}

struct TuiApp {
    config: Config,
    servers: Vec<LocalServer>,
    table_state: TableState,
    message: Option<String>,
    last_refresh: Instant,
}

impl TuiApp {
    fn new(config: Config) -> Self {
        let mut table_state = TableState::default();
        table_state.select(Some(0));

        Self {
            config,
            servers: Vec::new(),
            table_state,
            message: None,
            last_refresh: Instant::now() - REFRESH_INTERVAL,
        }
    }

    fn run(&mut self, terminal: &mut DefaultTerminal) -> Result<(), TuiError> {
        loop {
            if self.last_refresh.elapsed() >= REFRESH_INTERVAL {
                self.refresh()?;
            }

            terminal.draw(|frame| self.draw(frame))?;

            if !event::poll(Duration::from_millis(150))? {
                continue;
            }

            let Event::Key(key) = event::read()? else {
                continue;
            };
            if key.kind != KeyEventKind::Press {
                continue;
            }

            match key.code {
                KeyCode::Char('q') | KeyCode::Esc => return Ok(()),
                KeyCode::Char('r') => self.refresh()?,
                KeyCode::Down | KeyCode::Char('j') => self.select_next(),
                KeyCode::Up | KeyCode::Char('k') => self.select_previous(),
                KeyCode::Enter | KeyCode::Char('o') => self.open_selected(),
                KeyCode::Char('s') => self.start_selected(),
                KeyCode::Char('x') => self.kill_selected()?,
                KeyCode::Char('p') => self.toggle_pin_selected()?,
                KeyCode::Char('d') => self.remove_selected()?,
                _ => {}
            }
        }
    }

    fn refresh(&mut self) -> Result<(), TuiError> {
        let active_servers = scanner::scan(&self.config)?;
        let mut state = state::AppState::load()?;
        let servers = state.merge_servers(active_servers, &self.config);
        self.servers = state.visible_servers(servers, &self.config);
        state.save()?;
        self.last_refresh = Instant::now();
        self.clamp_selection();
        Ok(())
    }

    fn draw(&mut self, frame: &mut Frame) {
        let chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(3),
                Constraint::Min(8),
                Constraint::Length(7),
                Constraint::Length(2),
            ])
            .split(frame.area());

        frame.render_widget(self.header(), chunks[0]);
        self.draw_table(frame, chunks[1]);
        frame.render_widget(self.detail(), chunks[2]);
        frame.render_widget(self.footer(), chunks[3]);
    }

    fn header(&self) -> Paragraph<'_> {
        let active = self
            .servers
            .iter()
            .filter(|server| server.is_active())
            .count();
        let title = format!("Porchlight  {active} active / {} total", self.servers.len());
        Paragraph::new(title)
            .style(
                Style::default()
                    .fg(Color::Yellow)
                    .add_modifier(Modifier::BOLD),
            )
            .block(Block::default().borders(Borders::BOTTOM))
    }

    fn draw_table(&mut self, frame: &mut Frame, area: Rect) {
        let rows = self.servers.iter().map(|server| {
            let status = if server.is_active() { "●" } else { "○" };
            let status_style = if server.is_active() {
                Style::default().fg(Color::Green)
            } else {
                Style::default().fg(Color::DarkGray)
            };
            let group_label = server
                .group
                .as_ref()
                .map(|group| group.name.as_str())
                .unwrap_or("");
            let path = server
                .display_directory
                .as_deref()
                .unwrap_or("Unknown directory");
            let pin = if server.pinned { "★" } else { "" };

            Row::new([
                Cell::from(status).style(status_style),
                Cell::from(server.port.to_string()),
                Cell::from(server.server_type.as_str()),
                Cell::from(group_label),
                Cell::from(path),
                Cell::from(pin),
            ])
        });

        let table = Table::new(
            rows,
            [
                Constraint::Length(2),
                Constraint::Length(6),
                Constraint::Length(14),
                Constraint::Length(16),
                Constraint::Min(24),
                Constraint::Length(2),
            ],
        )
        .header(
            Row::new(["", "Port", "Type", "Group", "Directory", ""])
                .style(Style::default().fg(Color::DarkGray)),
        )
        .row_highlight_style(Style::default().bg(Color::DarkGray).fg(Color::White))
        .block(Block::default().borders(Borders::BOTTOM));

        frame.render_stateful_widget(table, area, &mut self.table_state);
    }

    fn detail(&self) -> Paragraph<'_> {
        let Some(server) = self.selected_server() else {
            return Paragraph::new(
                "No servers found. Start a local development server and refresh.",
            )
            .wrap(Wrap { trim: true });
        };

        let mut lines = vec![
            Line::from(vec![
                Span::styled("URL: ", label_style()),
                Span::raw(&server.url),
            ]),
            Line::from(vec![
                Span::styled("Process: ", label_style()),
                Span::raw(format!("pid {} • {}", server.pid, server.process_name)),
            ]),
            Line::from(vec![
                Span::styled("Command: ", label_style()),
                Span::raw(server.command.as_str()),
            ]),
        ];

        if let Some(start_command) = &server.start_command {
            lines.push(Line::from(vec![
                Span::styled("Start: ", label_style()),
                Span::raw(start_command.as_str()),
            ]));
        }

        if let Some(group) = &server.group {
            lines.push(Line::from(vec![
                Span::styled("Group: ", label_style()),
                Span::raw(format!(
                    "{} • {} • {} ({:.0}% from {})",
                    group.name,
                    group.kind,
                    group.role,
                    group.confidence * 100.0,
                    group.source
                )),
            ]));
        }

        if let Some(message) = &self.message {
            lines.push(Line::from(Span::styled(
                message,
                Style::default().fg(Color::Yellow),
            )));
        }

        Paragraph::new(lines).wrap(Wrap { trim: true })
    }

    fn footer(&self) -> Paragraph<'_> {
        Paragraph::new(
            "↑/↓ select  enter open  s start  x kill  p pin  d remove  r refresh  q quit",
        )
        .style(Style::default().fg(Color::DarkGray))
    }

    fn select_next(&mut self) {
        if self.servers.is_empty() {
            self.table_state.select(None);
            return;
        }

        let selected = self.table_state.selected().unwrap_or(0);
        self.table_state
            .select(Some((selected + 1) % self.servers.len()));
    }

    fn select_previous(&mut self) {
        if self.servers.is_empty() {
            self.table_state.select(None);
            return;
        }

        let selected = self.table_state.selected().unwrap_or(0);
        let previous = selected.checked_sub(1).unwrap_or(self.servers.len() - 1);
        self.table_state.select(Some(previous));
    }

    fn clamp_selection(&mut self) {
        if self.servers.is_empty() {
            self.table_state.select(None);
            return;
        }

        let selected = self
            .table_state
            .selected()
            .unwrap_or(0)
            .min(self.servers.len() - 1);
        self.table_state.select(Some(selected));
    }

    fn selected_server(&self) -> Option<&LocalServer> {
        self.table_state
            .selected()
            .and_then(|index| self.servers.get(index))
    }

    fn open_selected(&mut self) {
        let Some(server) = self.selected_server() else {
            return;
        };
        match Command::new("/usr/bin/open").arg(&server.url).status() {
            Ok(status) if status.success() => self.message = Some(format!("Opened {}", server.url)),
            Ok(status) => self.message = Some(format!("Open failed: {status}")),
            Err(error) => self.message = Some(format!("Open failed: {error}")),
        }
    }

    fn start_selected(&mut self) {
        let Some(server) = self.selected_server() else {
            return;
        };
        let Some(start_command) = &server.start_command else {
            self.message = Some("No start command saved for this server.".into());
            return;
        };

        let mut command = Command::new("/bin/sh");
        command.args(["-lc", start_command]);
        if let Some(directory) = &server.working_directory {
            command.current_dir(directory);
        }

        match command.spawn() {
            Ok(_) => self.message = Some(format!("Started {}", server.port)),
            Err(error) => self.message = Some(format!("Start failed: {error}")),
        }
    }

    fn kill_selected(&mut self) -> Result<(), TuiError> {
        let Some(server) = self.selected_server() else {
            return Ok(());
        };
        if !server.is_active() || server.pid == 0 {
            self.message = Some("Selected server is not active.".into());
            return Ok(());
        }

        let pid = server.pid.to_string();
        let status = Command::new("/bin/kill").arg(&pid).status()?;
        if status.success() {
            self.message = Some(format!("Killed pid {pid}"));
            self.refresh()?;
        } else {
            self.message = Some(format!("Kill failed: {status}"));
        }

        Ok(())
    }

    fn toggle_pin_selected(&mut self) -> Result<(), TuiError> {
        let Some(server) = self.selected_server() else {
            return Ok(());
        };
        let id = server.id.clone();
        let pinned = !server.pinned;
        let mut state = state::AppState::load()?;
        state.set_pinned(&id, pinned);
        state.save()?;
        self.message = Some(if pinned { "Pinned." } else { "Unpinned." }.into());
        self.refresh()?;
        Ok(())
    }

    fn remove_selected(&mut self) -> Result<(), TuiError> {
        let Some(server) = self.selected_server() else {
            return Ok(());
        };
        let id = server.id.clone();
        let mut state = state::AppState::load()?;
        let removed = state.remove(&id);
        state.save()?;
        self.message = Some(format!(
            "Removed {removed} server{}.",
            if removed == 1 { "" } else { "s" }
        ));
        self.refresh()?;
        Ok(())
    }
}

trait ServerStatusExt {
    fn is_active(&self) -> bool;
}

impl ServerStatusExt for LocalServer {
    fn is_active(&self) -> bool {
        self.status == ServerStatus::Active
    }
}

fn label_style() -> Style {
    Style::default()
        .fg(Color::DarkGray)
        .add_modifier(Modifier::BOLD)
}

#[derive(Debug, thiserror::Error)]
pub enum TuiError {
    #[error(transparent)]
    Io(#[from] io::Error),
    #[error(transparent)]
    Scanner(#[from] scanner::ScannerError),
    #[error(transparent)]
    State(#[from] state::StateError),
}
