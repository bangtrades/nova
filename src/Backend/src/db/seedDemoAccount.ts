/**
 * Demo Account Seeder (NOVA-304)
 *
 * Creates a demo account for App Store review
 * Email: demo@nova-app.com
 * Password: Demo1234!
 */

import { getPrismaClient } from './client';

export async function seedDemoAccount(): Promise<{ email: string; password: string }> {
  const prisma = getPrismaClient();

  const demoEmail = 'demo@nova-app.com';
  const demoPassword = 'Demo1234!';

  try {
    // Clean up existing demo account if it exists
    const existingUser = await (prisma as any).user.findUnique({
      where: { email: demoEmail },
    });

    if (existingUser) {
      console.log('Demo account already exists, skipping creation');
      return { email: demoEmail, password: demoPassword };
    }

    // Create demo parent user
    const demoUser = await (prisma as any).user.create({
      data: {
        displayName: 'Demo Parent',
        email: demoEmail,
      },
    });

    // Create subscription (pro tier, active)
    await (prisma as any).subscription.create({
      data: {
        userId: demoUser.id,
        plan: 'pro',
        status: 'active',
      },
    });

    // Create child 1: Alex (age 6, Explorer stage)
    const alex = await (prisma as any).childProfile.create({
      data: {
        userId: demoUser.id,
        name: 'Alex',
        birthDate: new Date('2020-04-13'), // Age 6
        currentStage: 1, // Explorer
      },
    });

    // Create child 2: Sam (age 8, Thinker stage)
    const sam = await (prisma as any).childProfile.create({
      data: {
        userId: demoUser.id,
        name: 'Sam',
        birthDate: new Date('2018-04-13'), // Age 8
        currentStage: 2, // Thinker
      },
    });

    // Create sample learning paths
    const computerPath = await (prisma as any).learningPath.create({
      data: {
        userId: demoUser.id,
        title: 'How Computers Think',
        description: 'Understanding the basics of computers',
        color: '#4ECDC4',
        icon: '💻',
        sortOrder: 1,
        stage: 1,
        isPremium: false,
      },
    });

    const robotPath = await (prisma as any).learningPath.create({
      data: {
        userId: demoUser.id,
        title: 'Robot Adventures',
        description: 'Explore the world of robots',
        color: '#FF6B6B',
        icon: '🤖',
        sortOrder: 2,
        stage: 1,
        isPremium: false,
      },
    });

    const aiPath = await (prisma as any).learningPath.create({
      data: {
        userId: demoUser.id,
        title: 'AI Explorers',
        description: 'Discover artificial intelligence',
        color: '#95E1D3',
        icon: '🧠',
        sortOrder: 3,
        stage: 1,
        isPremium: false,
      },
    });

    // Create sample lessons and cards for path 1
    const lesson1 = await (prisma as any).lesson.create({
      data: {
        pathId: computerPath.id,
        userId: demoUser.id,
        title: 'What is a Computer?',
        description: 'Introduction to computers',
        difficulty: 1,
        status: 'published',
        sortOrder: 1,
        publishedAt: new Date(),
      },
    });

    // Create cards for lesson 1
    const cardTypes = ['story', 'concept', 'concept', 'experiment', 'quiz', 'voice'];
    for (let i = 0; i < cardTypes.length; i++) {
      await (prisma as any).card.create({
        data: {
          lessonId: lesson1.id,
          type: cardTypes[i],
          sortOrder: i + 1,
          content: {
            text: `Demo card ${i + 1}`,
            title: `Card ${i + 1}`,
          },
          voiceScript: `This is demo card ${i + 1}`,
        },
      });
    }

    // Create another lesson
    const lesson2 = await (prisma as any).lesson.create({
      data: {
        pathId: computerPath.id,
        userId: demoUser.id,
        title: 'Binary & Bits',
        description: 'Understanding ones and zeros',
        difficulty: 1,
        status: 'published',
        sortOrder: 2,
        publishedAt: new Date(),
      },
    });

    // Create cards for lesson 2
    for (let i = 0; i < 6; i++) {
      await (prisma as any).card.create({
        data: {
          lessonId: lesson2.id,
          type: cardTypes[i],
          sortOrder: i + 1,
          content: {
            text: `Demo card ${i + 1}`,
            title: `Card ${i + 1}`,
          },
          voiceScript: `This is demo card ${i + 1}`,
        },
      });
    }

    // Create badges
    const exploreBadge = await (prisma as any).badge.create({
      data: {
        title: 'Explorer',
        description: 'Completed 5 lessons',
        icon: '🗺️',
        criteria: {
          type: 'lesson_completion',
          count: 5,
        },
      },
    });

    const firstLessonBadge = await (prisma as any).badge.create({
      data: {
        title: 'First Lesson',
        description: 'Completed your first lesson',
        icon: '🌟',
        criteria: {
          type: 'lesson_completion',
          count: 1,
        },
      },
    });

    // Award badges to children
    await (prisma as any).earnedBadge.create({
      data: {
        childId: alex.id,
        badgeId: firstLessonBadge.id,
      },
    });

    await (prisma as any).earnedBadge.create({
      data: {
        childId: sam.id,
        badgeId: exploreBadge.id,
      },
    });

    // Create learning sessions for demo data
    const alexSession = await (prisma as any).learningSession.create({
      data: {
        childId: alex.id,
        deviceId: 'demo-ipad-1',
        startedAt: new Date(Date.now() - 30 * 60 * 1000), // 30 minutes ago
      },
    });

    // Add card interactions
    const cards = await (prisma as any).card.findMany({
      where: { lessonId: lesson1.id },
      take: 3,
    });

    for (let i = 0; i < cards.length; i++) {
      await (prisma as any).cardInteraction.create({
        data: {
          sessionId: alexSession.id,
          cardId: cards[i].id,
          action: 'view',
          durationMs: Math.random() * 5000 + 3000,
          result: {
            completed: true,
            timestamp: new Date(),
          },
        },
      });
    }

    console.log('Demo account created successfully!');
    console.log(`Email: ${demoEmail}`);
    console.log(`Password: ${demoPassword}`);
    console.log(`Created children: Alex (6yo, Explorer) and Sam (8yo, Thinker)`);
    console.log(`Created 3 learning paths with sample lessons`);
    console.log(`Created 2 earned badges`);

    return { email: demoEmail, password: demoPassword };
  } catch (error) {
    console.error(`Demo account seeding failed: ${error}`);
    throw error;
  }
}
