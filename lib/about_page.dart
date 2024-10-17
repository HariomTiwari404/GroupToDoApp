import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Future<void> launchURL(String webUrl, String appUrl) async {
    if (kIsWeb) {
      // For web, open the website URL
      if (await canLaunch(webUrl)) {
        await launch(webUrl);
      } else {
        throw 'Could not launch $webUrl';
      }
    } else {
      // For mobile apps, try to open the app, and if that fails, open the web link
      if (await canLaunch(appUrl)) {
        await launch(appUrl);
      } else if (await canLaunch(webUrl)) {
        await launch(webUrl);
      } else {
        throw 'Could not launch $appUrl or $webUrl';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About This App'),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal, Colors.green],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Text(
                    'Hariom Tiwari',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'App Developer & Tech Enthusiast',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Connect with me:',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade800,
              ),
            ),
            const SizedBox(height: 10),
            buildSocialLink(
              context,
              icon: Icons.link_rounded,
              label: 'Twitter',
              color: Colors.blueAccent,
              onTap: () => launchURL(
                'https://x.com/HariomTiwari404',
                'twitter://user?screen_name=HariomTiwari404',
              ),
            ),
            buildSocialLink(
              context,
              icon: Icons.link_rounded,
              label: 'LinkedIn',
              color: Colors.blue.shade700,
              onTap: () => launchURL(
                'https://www.linkedin.com/in/hariomtiwari404/',
                'linkedin://in/hariomtiwari404',
              ),
            ),
            buildSocialLink(
              context,
              icon: Icons.link_rounded,
              label: 'YouTube',
              color: Colors.redAccent,
              onTap: () => launchURL(
                'https://www.youtube.com/@HariomTiwari_',
                'youtube://channel/@HariomTiwari_',
              ),
            ),
            const Spacer(),
            Center(
              child: Text(
                'Created by Hariom Tiwari',
                style: TextStyle(
                  fontSize: 14.0,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSocialLink(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: color, size: 28),
        title: Text(label, style: TextStyle(color: color, fontSize: 16)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
