# Autonomous Trader

> **Event-driven, AI-powered trading infrastructure for autonomous market agents**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)
[![Tests](https://github.com/alikhande70/autonomous-trader/actions/workflows/ci.yml/badge.svg)](https://github.com/alikhande70/autonomous-trader/actions)
[![Code style: black](https://img.shields.io/badge/code%20style-black-000000.svg)](https://github.com/psf/black)

## Overview

**Autonomous Trader** is an open-source framework for building, simulating, and deploying autonomous AI agents in financial markets. Built on event-driven architecture, it provides a foundation for:

- 🤖 **AI Agent Development**: Design intelligent agents that make autonomous trading decisions
- 📊 **Market Simulation**: Realistic event-driven backtesting with microsecond-precision timing
- 🔌 **Pluggable Integrations**: Connect to real exchanges, data feeds, and execution venues
- ⚡ **Low-Latency Runtime**: Optimized for high-frequency agent interactions
- 🎯 **Risk Management**: Built-in position monitoring, circuit breakers, and compliance

## Quick Start

### Installation

```bash
git clone https://github.com/alikhande70/autonomous-trader.git
cd autonomous-trader
pip install -e .
```

### Basic Agent Example

```python
from autonomous_trader.agents import BaseAgent
from autonomous_trader.market import MarketDataHandler
from autonomous_trader.events import OrderPlacedEvent

class SimpleAgent(BaseAgent):
    def __init__(self, agent_id: str, market_handler: MarketDataHandler):
        super().__init__(agent_id)
        self.market_handler = market_handler
    
    async def on_market_data(self, symbol: str, price: float):
        """React to market data and place orders."""
        decision = await self.analyze_signal(symbol, price)
        if decision.should_trade:
            order = self.create_order(
                symbol=symbol,
                quantity=decision.quantity,
                price=decision.price
            )
            await self.execute_order(order)
    
    async def analyze_signal(self, symbol: str, price: float):
        # Your ML/AI logic here
        return self.trading_decision(symbol, price)

# Run simulation
if __name__ == "__main__":
    agent = SimpleAgent("agent-1", market_handler)
    agent.run()
```

### Configuration

```yaml
# config/trading_config.yaml
agents:
  - id: agent-1
    strategy: momentum
    initial_capital: 100000
    risk_limit: 0.02

market:
  venue: simulation
  symbols: [AAPL, GOOGL, MSFT]
  data_source: historical_tick
  start_date: 2024-01-01
  end_date: 2024-12-31
```

## Architecture

```
autonomous-trader/
├── autonomous_trader/
│   ├── agents/          # Agent base classes & strategies
│   ├── market/          # Market data handling & order execution
│   ├── events/          # Event system core
│   ├── simulation/      # Backtesting engine
│   ├── persistence/     # State & history management
│   └── api/             # FastAPI server for agent control
├── tests/               # Comprehensive test suite
├── docs/                # Architecture & design docs
└── examples/            # Reference implementations
```

### Event-Driven Design

The framework uses a publish-subscribe event system:

```python
# Define custom events
class PortfolioRebalanceEvent(Event):
    agent_id: str
    timestamp: float
    target_allocation: Dict[str, float]

# Subscribe to events
event_bus.subscribe(PortfolioRebalanceEvent, handle_rebalance)

# Publish events
event_bus.publish(PortfolioRebalanceEvent(...))
```

## Key Features

### 1. **Autonomous Agents**
- Base agent framework with lifecycle management
- Multi-strategy support with composition
- State persistence across restarts

### 2. **Realistic Market Simulation**
- Microsecond-precision event timing
- Order book simulation with realistic fills
- Slippage, latency, and commission modeling

### 3. **Performance Monitoring**
- Real-time P&L tracking
- Greeks calculation (Delta, Gamma, Vega)
- Risk metrics (VaR, Sharpe, Maximum Drawdown)

### 4. **Integration Ready**
- REST API for remote agent control
- Data feed connectors (Polygon, Alpaca, IB)
- Exchange adapters (Simulated, Live, Paper)

## Development

### Environment Setup

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install dev dependencies
pip install -e ".[dev]"

# Run tests
pytest -v

# Run linting
black autonomous_trader/
isort autonomous_trader/
flake8 autonomous_trader/
```

### Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Performance Benchmarks

- **Simulation Speed**: 250K+ events/second on modern hardware
- **Agent Response Latency**: <1ms average decision time
- **Memory**: ~50MB per 1M historical quotes

## Roadmap

See [ROADMAP.md](ROADMAP.md) for planned features and milestones.

## Documentation

- [Architecture Guide](docs/architecture.md) - System design deep-dive
- [API Reference](docs/api.md) - Full API documentation
- [Examples](examples/) - Complete working examples
- [Security](SECURITY.md) - Security considerations and reporting

## License

MIT License © 2025 Autonomous Trader Contributors

## Support

- 📖 [Documentation](https://github.com/alikhande70/autonomous-trader/wiki)
- 🐛 [Report Issues](https://github.com/alikhande70/autonomous-trader/issues)
- 💬 [Discussions](https://github.com/alikhande70/autonomous-trader/discussions)

## Acknowledgments

Built with inspiration from modern financial infrastructure and distributed systems design patterns.

---

**Status**: Early-stage development. APIs subject to change. Production use not recommended until v1.0.
