import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';

void main() {
  runApp(const CvApp());
}

class CvApp extends StatelessWidget {
  const CvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Amir | Professional Portfolio',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F2027),
          primary: const Color(0xFF1e3c72),
          secondary: const Color(0xFF2a5298),
          tertiary: const Color(0xFF6c5ce7),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          color: Colors.white,
        ),
      ),
      home: const CvHomePage(),
    );
  }
}

class CvHomePage extends StatelessWidget {
  const CvHomePage({super.key});

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  void _showDownloadMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('📄 Generating Professional PDF...'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1e3c72),
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFDFF),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: ProfileHeader(onSocialTap: _launchURL),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Contact Info Row
                const ContactQuickInfo().animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 35),

                // Summary Section
                _buildSectionHeader(context, 'Professional Summary', FontAwesomeIcons.idCard),
                _buildExpandableCard(
                  'A dedicated Computer Science student at COMSATS University with a focus on Artificial Intelligence and Software Engineering. Proficient in Dart/Flutter and Java, with a strong foundation in database management. Passionate about creating efficient, scalable mobile and desktop applications. Committed to continuous learning and solving complex problems through innovative technology.',
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                const SizedBox(height: 35),

                // Skills Section
                _buildSectionHeader(context, 'Technical Expertise', FontAwesomeIcons.terminal),
                const TechnicalSkillsGrid().animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 35),

                // Education Section
                _buildSectionHeader(context, 'Education', FontAwesomeIcons.graduationCap),
                const EducationCard().animate().fadeIn(delay: 400.ms).slideX(begin: 0.1),

                const SizedBox(height: 35),

                // Projects Section
                _buildSectionHeader(context, 'Featured Projects', FontAwesomeIcons.rocket),
                Column(
                  children: [
                    _buildProjectCard(
                      context,
                      'Import-Export Manager',
                      'Enterprise-level desktop solution for supply chain logistics and transaction tracking.',
                      ['Java', 'SQL Server', 'Swing'],
                      FontAwesomeIcons.ship,
                    ),
                    const SizedBox(height: 15),
                    _buildProjectCard(
                      context,
                      'Smart Inventory System',
                      'Automated inventory tracking with real-time stock alerts and analytics.',
                      ['Java', 'SQL', 'OOP'],
                      FontAwesomeIcons.warehouse,
                    ),
                    const SizedBox(height: 15),
                    _buildProjectCard(
                      context,
                      'Multi-utility Flutter App',
                      'Cross-platform mobile apps featuring localized storage and sleek Material 3 UI.',
                      ['Flutter', 'Dart', 'Firebase'],
                      FontAwesomeIcons.mobileScreen,
                    ),
                  ],
                ).animate().fadeIn(delay: 500.ms),

                const SizedBox(height: 35),

                // Languages & Interests
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(context, 'Languages', FontAwesomeIcons.language),
                          _buildMiniCard('Urdu (Native)'),
                          _buildMiniCard('English (Proficient)'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(context, 'Interests', FontAwesomeIcons.heart),
                          _buildMiniCard('Machine Learning'),
                          _buildMiniCard('Cyber Security'),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 600.ms),

                const SizedBox(height: 50),

                // Footer / Download Button
                Center(
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showDownloadMessage(context),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('DOWNLOAD FULL RESUME'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                          backgroundColor: const Color(0xFF1e3c72),
                          foregroundColor: Colors.white,
                          elevation: 10,
                          shadowColor: const Color(0xFF1e3c72).withOpacity(0.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Built with Flutter ❤️ by Amir',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 700.ms).scale(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1e3c72).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: FaIcon(icon, size: 16, color: const Color(0xFF1e3c72)),
          ),
          const SizedBox(width: 15),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: const Color(0xFF1e3c72),
            ),
          ),
          const Expanded(child: Divider(indent: 15, thickness: 1, color: Color(0xFFEEEEEE))),
        ],
      ),
    );
  }

  Widget _buildExpandableCard(String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(height: 1.7, fontSize: 15, color: Colors.grey.shade800),
      ),
    );
  }

  Widget _buildMiniCard(String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, String title, String desc, List<String> tags, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(icon, size: 22, color: const Color(0xFF6c5ce7)),
              const SizedBox(width: 15),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1e3c72)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            desc,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                tag,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class ContactQuickInfo extends StatelessWidget {
  const ContactQuickInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildItem(context, Icons.phone_android, '+92 300 1234567'),
        _buildItem(context, Icons.location_on_rounded, 'Vehari, Pakistan'),
      ],
    );
  }

  Widget _buildItem(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF1e3c72)),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class TechnicalSkillsGrid extends StatelessWidget {
  const TechnicalSkillsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSkillRow('Languages', ['Java', 'Dart', 'Python', 'C++']),
        const SizedBox(height: 15),
        _buildSkillRow('Frameworks', ['Flutter', 'Spring Boot', 'Material UI']),
        const SizedBox(height: 15),
        _buildSkillRow('Databases', ['SQL Server', 'MongoDB', 'Firebase']),
      ],
    );
  }

  Widget _buildSkillRow(String category, List<String> skills) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: skills.map((s) => Chip(
            label: Text(s),
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.grey.shade200),
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            padding: const EdgeInsets.symmetric(horizontal: 5),
          )).toList(),
        ),
      ],
    );
  }
}

class EducationCard extends StatelessWidget {
  const EducationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1e3c72).withOpacity(0.05), Colors.white],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1e3c72).withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF1e3c72),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COMSATS University Islamabad',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'BS in Computer Science (Vehari Campus)',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 5),
                const Text(
                  '2023 - 2027',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF6c5ce7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileHeader extends StatelessWidget {
  final Function(String) onSocialTap;

  const ProfileHeader({super.key, required this.onSocialTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            children: [
              Hero(
                tag: 'profile-pic',
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const CircleAvatar(
                      radius: 65,
                      backgroundImage: AssetImage('assets/images/amir.jpeg'),
                    ),
                  ),
                ),
              ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

              const SizedBox(height: 25),

              Text(
                'AMIR',
                style: GoogleFonts.poppins(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),

              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Text(
                  'COMPUTER SCIENCE STUDENT',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 35),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialButton(FontAwesomeIcons.github, 'https://github.com/amir'),
                  _buildSocialButton(FontAwesomeIcons.linkedinIn, 'https://linkedin.com/in/amir'),
                  _buildSocialButton(FontAwesomeIcons.envelope, 'mailto:amir@student.comsats.edu.pk'),
                  _buildSocialButton(FontAwesomeIcons.whatsapp, 'https://wa.me/923001234567'),
                ],
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: () => onSocialTap(url),
        borderRadius: BorderRadius.circular(50),
        child: Container(
          height: 45,
          width: 45,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Center(child: FaIcon(icon, color: Colors.white, size: 18)),
        ),
      ),
    );
  }
}
