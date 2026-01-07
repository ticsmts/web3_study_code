# MemeFactory Frontend | Liquid Crystal Aesthetic

A hyper-modern frontend for the ERC20MemeFactory project, designed with **Glassmorphism** and **Neumorphism** principles.

## 🎨 Design Philosophy

- **Glassmorphism**: Surfaces use high backdrop-blur and translucency to create a sense of depth and hierarchy.
- **Neumorphism**: Tactile input fields and buttons provide physical presence in a digital space.
- **Atmospheric Depth**: Dynamic radial gradients and mesh backgrounds create a premium, immersive environment.
- **Motion System**: Staggered entry animations (reveal-up) and smooth state transitions via Framer Motion.

## 🛠️ Tech Stack

- **React**: Component-based UI.
- **Vite**: Ultra-fast build tool and dev server.
- **Ethers.js v6**: High-performance blockchain interaction.
- **Framer Motion**: State-of-the-art animations.
- **Lucide React**: Refined, lightweight iconography.

## 🚀 Features

- **Dynamic Token Tracking**: Real-time listing of all factory-deployed tokens.
- **Smart Buy Routing**: Integration with the `buyMeme` contract function that compares DEX vs Mint prices.
- **Interactive Deploy Form**: Neumorphic form fields with validation.
- **Apple-Inspired Progress Bar**: Smooth, high-fidelity minting progress tracking.

## 📦 Getting Started

1. Ensure the `MemeFactory` contract is deployed (default Anvil address used in `constants.js`).
2. Run `npm install` in this directory.
3. Start the dev server: `npm run dev`.
