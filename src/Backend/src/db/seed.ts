import { getPrismaClient, toJsonColumn } from './client';

async function seed(): Promise<void> {
  const prisma = getPrismaClient();

  // Clean up existing data (for fresh seed)
  await prisma.earnedBadge.deleteMany();
  await prisma.badge.deleteMany();
  await prisma.cardInteraction.deleteMany();
  await prisma.learningSession.deleteMany();
  await prisma.card.deleteMany();
  await prisma.lesson.deleteMany();
  await prisma.learningPath.deleteMany();
  await prisma.childProfile.deleteMany();
  await prisma.subscription.deleteMany();
  await prisma.lLMProvider.deleteMany();
  await prisma.user.deleteMany();

  // Create test user
  const testUser = await prisma.user.create({
    data: {
      displayName: 'Test Parent',
      email: 'parent@nova-app.com',
    },
  });

  // Create child profile (age 4)
  const child = await prisma.childProfile.create({
    data: {
      userId: testUser.id,
      name: 'Explorer',
      birthDate: new Date('2020-04-13'),
      currentStage: 1,
    },
  });

  // Create subscription
  await prisma.subscription.create({
    data: {
      userId: testUser.id,
      plan: 'free',
      status: 'active',
    },
  });

  // Create learning paths
  const aiPath = await prisma.learningPath.create({
    data: {
      userId: testUser.id,
      title: 'What is AI?',
      description: 'Introduction to artificial intelligence for young learners',
      color: '#FF6B6B',
      icon: '🤖',
      sortOrder: 1,
      stage: 1,
      isPremium: false,
    },
  });

  const computerPath = await prisma.learningPath.create({
    data: {
      userId: testUser.id,
      title: 'How Computers Think',
      description: 'Understanding the basics of how computers work',
      color: '#4ECDC4',
      icon: '💻',
      sortOrder: 2,
      stage: 1,
      isPremium: false,
    },
  });

  const robotPath = await prisma.learningPath.create({
    data: {
      userId: testUser.id,
      title: 'Talk to Robots',
      description: 'Learning to communicate with AI assistants',
      color: '#95E1D3',
      icon: '🗣️',
      sortOrder: 3,
      stage: 1,
      isPremium: false,
    },
  });

  // Create lesson 1: What is a Computer?
  const lesson1 = await prisma.lesson.create({
    data: {
      pathId: computerPath.id,
      userId: testUser.id,
      title: 'What is a Computer?',
      description: 'A fun introduction to computers for 4-year-olds',
      difficulty: 1,
      status: 'published',
      sortOrder: 1,
      publishedAt: new Date(),
    },
  });

  // Create cards for lesson 1
  await prisma.card.create({
    data: {
      lessonId: lesson1.id,
      type: 'story',
      sortOrder: 1,
      content: toJsonColumn({
        text: 'Once upon a time, there was a magical box called a computer.',
        imageUrl: 'https://assets.nova-app.com/story-1.png',
      }),
      voiceScript: 'Once upon a time, there was a magical box called a computer.',
    },
  });

  await prisma.card.create({
    data: {
      lessonId: lesson1.id,
      type: 'concept',
      sortOrder: 2,
      content: toJsonColumn({
        title: 'Computers are smart helpers',
        description: 'They can remember things, do math, and show us pictures!',
      }),
      voiceScript: 'Computers are smart helpers. They can remember things, do math, and show us pictures!',
    },
  });

  await prisma.card.create({
    data: {
      lessonId: lesson1.id,
      type: 'story',
      sortOrder: 3,
      content: toJsonColumn({
        text: 'Your iPad is a computer too! It helps you play games and watch videos.',
        imageUrl: 'https://assets.nova-app.com/story-2.png',
      }),
      voiceScript: 'Your iPad is a computer too! It helps you play games and watch videos.',
    },
  });

  await prisma.card.create({
    data: {
      lessonId: lesson1.id,
      type: 'interactive',
      sortOrder: 4,
      content: toJsonColumn({
        question: 'What does a computer help us do?',
        options: ['Play', 'Learn', 'Draw', 'All of the above!'],
        correctAnswer: 3,
      }),
      interactionConfig: toJsonColumn({
        type: 'multipleChoice',
        allowRetry: true,
      }),
    },
  });

  await prisma.card.create({
    data: {
      lessonId: lesson1.id,
      type: 'story',
      sortOrder: 5,
      content: toJsonColumn({
        text: 'Now you know what a computer is! Great job, explorer!',
        imageUrl: 'https://assets.nova-app.com/celebration.png',
      }),
      voiceScript: 'Now you know what a computer is! Great job, explorer!',
    },
  });

  // Create lesson 2: Computer Magic
  const lesson2 = await prisma.lesson.create({
    data: {
      pathId: computerPath.id,
      userId: testUser.id,
      title: 'Computer Magic',
      description: 'Explore what makes computers special and magical',
      difficulty: 1,
      status: 'published',
      sortOrder: 2,
      publishedAt: new Date(),
    },
  });

  // Create cards for lesson 2
  await prisma.card.create({
    data: {
      lessonId: lesson2.id,
      type: 'story',
      sortOrder: 1,
      content: toJsonColumn({
        text: 'Computers have special powers called "programs" inside them.',
        imageUrl: 'https://assets.nova-app.com/magic-1.png',
      }),
      voiceScript: 'Computers have special powers called programs inside them.',
    },
  });

  await prisma.card.create({
    data: {
      lessonId: lesson2.id,
      type: 'concept',
      sortOrder: 2,
      content: toJsonColumn({
        title: 'Programs are like recipes',
        description: 'They tell the computer exactly what to do, step by step!',
      }),
      voiceScript: 'Programs are like recipes. They tell the computer exactly what to do, step by step!',
    },
  });

  await prisma.card.create({
    data: {
      lessonId: lesson2.id,
      type: 'story',
      sortOrder: 3,
      content: toJsonColumn({
        text: 'When you tap a button, you are telling the computer to follow a program!',
        imageUrl: 'https://assets.nova-app.com/magic-2.png',
      }),
      voiceScript: 'When you tap a button, you are telling the computer to follow a program!',
    },
  });

  await prisma.card.create({
    data: {
      lessonId: lesson2.id,
      type: 'interactive',
      sortOrder: 4,
      content: toJsonColumn({
        question: 'What do programs tell computers to do?',
        options: ['Sleep', 'Sing', 'What to do step by step', 'Nothing'],
        correctAnswer: 2,
      }),
      interactionConfig: toJsonColumn({
        type: 'multipleChoice',
        allowRetry: true,
      }),
    },
  });

  await prisma.card.create({
    data: {
      lessonId: lesson2.id,
      type: 'story',
      sortOrder: 5,
      content: toJsonColumn({
        text: 'You are becoming a computer expert!',
        imageUrl: 'https://assets.nova-app.com/celebration-2.png',
      }),
      voiceScript: 'You are becoming a computer expert!',
    },
  });

  // Create badges
  const firstLessonBadge = await prisma.badge.create({
    data: {
      title: 'First Lesson',
      description: 'Completed your first lesson!',
      icon: '🌟',
      criteria: toJsonColumn({
        type: 'lesson_completion',
        count: 1,
      }),
    },
  });

  const explorerBadge = await prisma.badge.create({
    data: {
      title: 'Explorer',
      description: 'Completed 5 lessons!',
      icon: '🗺️',
      criteria: toJsonColumn({
        type: 'lesson_completion',
        count: 5,
      }),
    },
  });

  const curiousMindBadge = await prisma.badge.create({
    data: {
      title: 'Curious Mind',
      description: 'Answered 10 questions correctly!',
      icon: '🧠',
      criteria: toJsonColumn({
        type: 'correct_answers',
        count: 10,
      }),
    },
  });

  // Award first badge to child
  await prisma.earnedBadge.create({
    data: {
      childId: child.id,
      badgeId: firstLessonBadge.id,
    },
  });

  // Create a sample learning session
  const session = await prisma.learningSession.create({
    data: {
      childId: child.id,
      deviceId: 'ipad-simulator',
      startedAt: new Date(Date.now() - 15 * 60 * 1000), // 15 minutes ago
    },
  });

  // Create sample interactions
  const cards = await prisma.card.findMany({
    where: { lessonId: lesson1.id },
  });

  for (let i = 0; i < Math.min(2, cards.length); i++) {
    await prisma.cardInteraction.create({
      data: {
        sessionId: session.id,
        cardId: cards[i]!.id,
        action: 'view',
        durationMs: Math.random() * 5000 + 2000,
        result: toJsonColumn({
          completed: true,
          timestamp: new Date(),
        }),
      },
    });
  }

  console.log('Database seeded successfully!');
  console.log(`Created test user: ${testUser.email}`);
  console.log(`Created child: ${child.name} (age 4)`);
  console.log(`Created 3 learning paths with 2 lessons (5 cards each)`);
  console.log(`Created 3 badges`);
}

seed().catch((error) => {
  console.error('Seed failed:', error);
  process.exit(1);
});
